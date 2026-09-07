#!/bin/bash

# vars must actually have been attempted - that is the lesson
grep -q "^vars:" /root/app/prod/kustomization.yaml 2>/dev/null || exit 1

# and the render must show the placeholder surviving unsubstituted, which is
# the silent failure this step exists to demonstrate
RENDER=$(kubectl kustomize /root/app/prod 2>/dev/null)
echo "$RENDER" | grep -q 'BACKEND_HOST: \$(BACKEND_NAME)' || exit 1

# the deprecation warning must be on stderr, not stdout - the reason it goes
# unnoticed in a pipeline
WARN=$(kubectl kustomize /root/app/prod 2>&1 >/dev/null)
echo "$WARN" | grep -qi "deprecated" || exit 1

exit 0
