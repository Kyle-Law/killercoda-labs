#!/bin/bash

for i in $(seq 1 3); do
  READY=$(kubectl get rs whoami-web -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" == "3" ] || exit 1
  sleep 5
done

# every Pod must be owned directly by the ReplicaSet - no Deployment in the chain
OWNERS=$(kubectl get pod -l app=whoami-web -o jsonpath='{range .items[*]}{.metadata.ownerReferences[0].kind}:{.metadata.ownerReferences[0].name}{"\n"}{end}')
[ -n "$OWNERS" ] || exit 1
echo "$OWNERS" | grep -v "^ReplicaSet:whoami-web$" && exit 1

exit 0
