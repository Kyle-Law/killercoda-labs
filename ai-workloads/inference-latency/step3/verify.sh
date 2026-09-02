#!/bin/bash

# prefill's per-token cost must be off, and decode on - the inverse of step 2
kubectl get configmap sim-config -o jsonpath='{.data.config\.yaml}' 2>/dev/null \
  | grep -qE '^\s*prefill-time-per-token:\s*"?0m?s?"?\s*$' || exit 1
kubectl get configmap sim-config -o jsonpath='{.data.config\.yaml}' 2>/dev/null \
  | grep -qE '^\s*inter-token-latency:\s*"20ms"\s*$' || exit 1

[ -s /root/decode-short ] || exit 1
[ -s /root/decode-long ] || exit 1

S=$(tr -d '[:space:]' < /root/decode-short)
L=$(tr -d '[:space:]' < /root/decode-long)

python3 -c "
import sys
try: s=float('$S'); l=float('$L')
except Exception: sys.exit(1)
sys.exit(0 if (l - s) >= 0.8 else 1)
"
