#!/bin/bash

kubectl get deployment shop >/dev/null 2>&1 || exit 1

# All four safety settings must be in place.
PROBE=$(kubectl get deployment shop -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' 2>/dev/null)
[ -n "$PROBE" ] || exit 1

MRS=$(kubectl get deployment shop -o jsonpath='{.spec.minReadySeconds}' 2>/dev/null)
[ -n "$MRS" ] || exit 1
# Must out-last the 25s window in which a bad replica still looks healthy.
[ "$MRS" -gt 25 ] 2>/dev/null || exit 1

MAXUNAVAIL=$(kubectl get deployment shop -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}' 2>/dev/null)
[ "$MAXUNAVAIL" == "0" ] || exit 1

PDS=$(kubectl get deployment shop -o jsonpath='{.spec.progressDeadlineSeconds}' 2>/dev/null)
[ -n "$PDS" ] || exit 1
[ "$PDS" -le 300 ] 2>/dev/null || exit 1

# The flapping release must actually have been attempted against them.
CMD=$(kubectl get deployment shop -o jsonpath='{.spec.template.spec.containers[0].command}' 2>/dev/null)
echo "$CMD" | grep -q "readyz/disable" || exit 1

for i in $(seq 1 36); do
  AVAIL=$(kubectl get deployment shop -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
  [ -z "$AVAIL" ] && AVAIL=0
  UPDATED=$(kubectl get deployment shop -o jsonpath='{.status.updatedReplicas}' 2>/dev/null)
  [ -z "$UPDATED" ] && UPDATED=0
  PROGRESSING=$(kubectl get deployment shop \
    -o jsonpath='{range .status.conditions[?(@.type=="Progressing")]}{.reason}{end}' 2>/dev/null)

  # Full capacity retained, the bad release never took over, and the
  # Deployment reported the failure rather than hanging or claiming success.
  if [ "$AVAIL" == "4" ] && [ "$UPDATED" -lt 4 ] && [ "$PROGRESSING" == "ProgressDeadlineExceeded" ]; then
    CODE=$(curl -s -m 2 -o /dev/null -w '%{http_code}' http://localhost:30080/ 2>/dev/null)
    [ "$CODE" == "200" ] && exit 0
  fi
  sleep 5
done

exit 1
