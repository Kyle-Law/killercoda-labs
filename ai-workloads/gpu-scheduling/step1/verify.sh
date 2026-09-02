#!/bin/bash

NODE=$(cat /root/nodename 2>/dev/null)
[ -n "$NODE" ] || exit 1

# must be advertised in allocatable, not just capacity - allocatable is what
# the scheduler actually places against
ALLOC=$(kubectl get node "$NODE" -o jsonpath='{.status.allocatable.nvidia\.com/gpu}' 2>/dev/null)
[ "$ALLOC" == "4" ] || exit 1

exit 0
