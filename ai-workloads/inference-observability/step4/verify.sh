#!/bin/bash

# the rule must exist in Prometheus, not just in a ConfigMap on disk
for i in $(seq 1 12); do
  curl -s --max-time 5 http://localhost:30900/api/v1/rules 2>/dev/null \
    | grep -q "HighInferenceQueueDepth" && break
  sleep 5
done
curl -s --max-time 5 http://localhost:30900/api/v1/rules 2>/dev/null \
  | grep -q "HighInferenceQueueDepth" || exit 1

# and it must actually reach the firing state - proving the synthetic signal
# drove the rule end to end, rather than the rule merely being loaded
for i in $(seq 1 30); do
  STATE=$(curl -s --max-time 5 -G http://localhost:30900/api/v1/query \
      --data-urlencode 'query=ALERTS{alertname="HighInferenceQueueDepth"}' 2>/dev/null \
    | python3 -c "
import sys,json
try:
    r=json.load(sys.stdin).get('data',{}).get('result',[])
    print(','.join(x['metric'].get('alertstate','') for x in r))
except Exception: print('')
" 2>/dev/null)
  echo "$STATE" | grep -q "firing" && exit 0
  sleep 5
done

exit 1
