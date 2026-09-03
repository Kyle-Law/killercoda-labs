#!/bin/bash

kubectl get deployment slow-starter >/dev/null 2>&1 || exit 1

# The app and how it starts must be untouched -- the point of the step is that
# the application was never the problem.
CMD=$(kubectl get deployment slow-starter -o jsonpath='{.spec.template.spec.containers[0].command}' 2>/dev/null)
echo "$CMD" | grep -q "sleep 60" || exit 1
IMAGE=$(kubectl get deployment slow-starter -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
echo "$IMAGE" | grep -q "podinfo" || exit 1

# The liveness probe that was killing it must be gone.
LIVENESS=$(kubectl get deployment slow-starter -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}' 2>/dev/null)
[ -z "$LIVENESS" ] || exit 1

# And it must actually reach Ready, having survived its full startup.
for i in $(seq 1 40); do
  READY=$(kubectl get deployment slow-starter -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" == "1" ] && exit 0
  sleep 5
done

exit 1
