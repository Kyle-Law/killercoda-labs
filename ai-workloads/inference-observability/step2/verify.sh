#!/bin/bash

[ -s /root/ttft-p95 ] || exit 1

VAL=$(tr -d '[:space:]"' < /root/ttft-p95)
# must be a number
python3 -c "
import sys
try: v=float('$VAL')
except Exception: sys.exit(1)
# a configured 2s TTFT lands in the (1.0, 2.5] bucket, so the interpolated p95
# must sit clearly above the sub-second buckets. The band is deliberately wide:
# the point is that it reflects the configured latency, not that it hits an
# exact interpolated value.
sys.exit(0 if 1.0 <= v <= 5.0 else 1)
" || exit 1

# and the histogram must really be populated in Prometheus right now
for i in $(seq 1 12); do
  N=$(curl -s --max-time 5 -G http://localhost:30900/api/v1/query \
      --data-urlencode 'query=sum(vllm:time_to_first_token_seconds_count)' 2>/dev/null \
    | python3 -c "
import sys,json
try:
    r=json.load(sys.stdin).get('data',{}).get('result',[])
    print(r[0]['value'][1] if r else '0')
except Exception: print('0')
" 2>/dev/null)
  python3 -c "import sys; sys.exit(0 if float('${N:-0}') > 0 else 1)" 2>/dev/null && exit 0
  sleep 5
done

exit 1
