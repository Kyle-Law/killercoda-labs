#!/bin/bash

# both probes must be present, and on the correct endpoints - swapping them
# is the mistake this step exists to prevent
LIVE=$(kubectl get deployment sim -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.httpGet.path}' 2>/dev/null)
READY=$(kubectl get deployment sim -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}' 2>/dev/null)
[ "$LIVE" == "/health" ] || exit 1
[ "$READY" == "/health/ready" ] || exit 1

# the recorded status must be the injected one
grep -q "503" /root/injected-status 2>/dev/null || exit 1

# and the deployment must still be healthy with those probes wired up -
# a probe pointed at the wrong port would leave it never becoming Ready
for i in $(seq 1 24); do
  AVAIL=$(kubectl get deployment sim -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [ "$AVAIL" == "1" ]; then
    # confirm injection is live rather than a stale file
    CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
      http://localhost:30800/v1/chat/completions \
      -H 'Content-Type: application/json' -H 'X-Return-Error: 503' \
      -d '{"model":"dummy-model","messages":[{"role":"user","content":"x"}]}' 2>/dev/null)
    [ "$CODE" == "503" ] && exit 0
  fi
  sleep 5
done

exit 1
