#!/bin/bash

kubectl get daemonset node-agent >/dev/null 2>&1 || exit 1

ORIGINAL_UID=$(tr -d '[:space:]' < /root/original-node-agent-uid.txt 2>/dev/null)
[ -n "$ORIGINAL_UID" ] || exit 1

PODNAME=$(kubectl get pod -l app=node-agent -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -n "$PODNAME" ] || exit 1

# the whole point of the exercise: this must be the SAME Pod object, not a
# fresh one created by an ordinary (cascading) delete + recreate
CURRENT_UID=$(kubectl get pod "$PODNAME" -o jsonpath='{.metadata.uid}' 2>/dev/null)
[ "$CURRENT_UID" == "$ORIGINAL_UID" ] || exit 1

RESTARTS=$(kubectl get pod "$PODNAME" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)
[ "$RESTARTS" == "0" ] || exit 1

OWNER_KIND=$(kubectl get pod "$PODNAME" -o jsonpath='{.metadata.ownerReferences[0].kind}' 2>/dev/null)
[ "$OWNER_KIND" == "DaemonSet" ] || exit 1

OWNER_NAME=$(kubectl get pod "$PODNAME" -o jsonpath='{.metadata.ownerReferences[0].name}' 2>/dev/null)
[ "$OWNER_NAME" == "node-agent" ]
