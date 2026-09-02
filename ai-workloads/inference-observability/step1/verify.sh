#!/bin/bash

kubectl get deployment prometheus >/dev/null 2>&1 || exit 1

PORT=$(kubectl get svc prometheus -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
[ "$PORT" == "30900" ] || exit 1

# Prometheus must actually be scraping the simulator - up==1 for that job.
# Querying through the API proves the whole path, not just that Pods exist.
for i in $(seq 1 24); do
  VAL=$(curl -s --max-time 5 'http://localhost:30900/api/v1/query?query=up%7Bjob%3D%22vllm-sim%22%7D' 2>/dev/null \
    | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    r=d.get('data',{}).get('result',[])
    print(r[0]['value'][1] if r else '')
except Exception: print('')
" 2>/dev/null)
  [ "$VAL" == "1" ] && exit 0
  sleep 5
done

exit 1
