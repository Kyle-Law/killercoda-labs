#!/bin/bash

# the memory-hungry pod must be gone
if kubectl get pod mem-hog >/dev/null 2>&1; then exit 1; fi

# the light one should still be there - proves they targeted the right
# Pod instead of just clearing everything
kubectl get pod mem-light >/dev/null 2>&1
