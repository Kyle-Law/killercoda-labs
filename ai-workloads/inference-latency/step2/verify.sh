#!/bin/bash

# decode must actually be switched off, otherwise this isn't measuring prefill
kubectl get configmap sim-config -o jsonpath='{.data.config\.yaml}' 2>/dev/null \
  | grep -qE '^\s*inter-token-latency:\s*"?0m?s?"?\s*$' || exit 1
kubectl get configmap sim-config -o jsonpath='{.data.config\.yaml}' 2>/dev/null \
  | grep -qE '^\s*prefill-time-per-token:\s*"20ms"\s*$' || exit 1

[ -s /root/prefill-short ] || exit 1
[ -s /root/prefill-long ] || exit 1

S=$(tr -d '[:space:]' < /root/prefill-short)
L=$(tr -d '[:space:]' < /root/prefill-long)

# the long prompt must take materially longer - that IS the lesson. 90 extra
# tokens x 20ms = ~1.8s expected; require at least 0.8s to allow for jitter
# and a slow box, while still ruling out "no difference".
python3 -c "
import sys
try: s=float('$S'); l=float('$L')
except Exception: sys.exit(1)
sys.exit(0 if (l - s) >= 0.8 else 1)
"
