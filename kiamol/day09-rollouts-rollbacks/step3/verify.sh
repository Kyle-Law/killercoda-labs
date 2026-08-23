#!/bin/bash

STARTING=$(tr -d '[:space:]' < /root/api-starting-revision.txt 2>/dev/null)
[ -n "$STARTING" ] || exit 1

IMG=""
ENVVAL=""
READY=""
for i in $(seq 1 12); do
  IMG=$(kubectl get deployment api -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  ENVVAL=$(kubectl get deployment api -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="RELEASE_NOTES")].value}' 2>/dev/null)
  READY=$(kubectl get deployment api -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$IMG" == "nginx:1.26-alpine" ] && [ "$ENVVAL" == "batched-update" ] && [ "$READY" == "2" ] && break
  sleep 5
done
[ "$IMG" == "nginx:1.26-alpine" ] && [ "$ENVVAL" == "batched-update" ] && [ "$READY" == "2" ] || exit 1

PAUSED=$(kubectl get deployment api -o jsonpath='{.spec.paused}' 2>/dev/null)
[ "$PAUSED" != "true" ] || exit 1

# find the revision of whichever ReplicaSet is currently scaled up - avoids
# relying on jsonpath filter numeric comparison, which isn't something I've
# verified works reliably here; plain awk on extracted fields instead
CURRENT_REV=$(kubectl get rs -l app=api -o jsonpath='{range .items[*]}{.spec.replicas}:{.metadata.annotations.deployment\.kubernetes\.io/revision}{"\n"}{end}' 2>/dev/null | awk -F: '$1>0{print $2}')

EXPECTED_REV=$((STARTING + 1))
[ "$CURRENT_REV" == "$EXPECTED_REV" ]
