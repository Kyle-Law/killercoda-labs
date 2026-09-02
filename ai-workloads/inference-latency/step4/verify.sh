#!/bin/bash

kubectl get configmap sim-config -o jsonpath='{.data.config\.yaml}' 2>/dev/null \
  | grep -qE '^\s*prefill-time-per-token:\s*"20ms"\s*$' || exit 1
kubectl get configmap sim-config -o jsonpath='{.data.config\.yaml}' 2>/dev/null \
  | grep -qE '^\s*inter-token-latency:\s*"20ms"\s*$' || exit 1

[ -s /root/prediction ] || exit 1
[ -s /root/measured ] || exit 1

P=$(tr -d '[:space:]' < /root/prediction)
M=$(tr -d '[:space:]' < /root/measured)

python3 -c "
import sys
try: p=float('$P'); m=float('$M')
except Exception: sys.exit(1)
# the measurement must land near the model's prediction of ~2.5s
if not (1.5 <= m <= 5.0): sys.exit(1)
# and the prediction must be a real derivation, not a copy of the measurement
# or an arbitrary number - within 1s of the model's answer
sys.exit(0 if abs(p - 2.5) <= 1.0 else 1)
"
