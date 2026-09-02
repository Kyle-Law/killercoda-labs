#!/bin/bash

# the concurrency limit must actually have been lowered
kubectl get configmap sim-config -o jsonpath='{.data.config\.yaml}' 2>/dev/null \
  | grep -qE '^\s*max-num-seqs:\s*2\s*$' || exit 1

# and Prometheus must have observed the queue actually building. A gauge only
# shows non-zero while requests are queued, so ask for the max over a window
# rather than the instantaneous value.
for i in $(seq 1 24); do
  MAXQ=$(curl -s --max-time 5 -G http://localhost:30900/api/v1/query \
      --data-urlencode 'query=max_over_time(vllm:num_requests_waiting[15m])' 2>/dev/null \
    | python3 -c "
import sys,json
try:
    r=json.load(sys.stdin).get('data',{}).get('result',[])
    print(max((float(x['value'][1]) for x in r), default=0))
except Exception: print(0)
" 2>/dev/null)
  python3 -c "import sys; sys.exit(0 if float('${MAXQ:-0}') >= 1 else 1)" 2>/dev/null && exit 0
  sleep 5
done

exit 1
