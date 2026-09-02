#!/bin/bash

[ -s /root/baseline ] || exit 1

VAL=$(tr -d '[:space:]' < /root/baseline)
# 2s prefill-overhead + ~7 x 200ms decode ~= 3.4s. Wide band: the point is that
# the measurement reflects the configured latency, not an exact value.
python3 -c "
import sys
try: v=float('$VAL')
except Exception: sys.exit(1)
sys.exit(0 if 2.0 <= v <= 8.0 else 1)
" || exit 1

exit 0
