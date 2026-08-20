#!/bin/bash

TAINTED_NODE=$(tr -d '[:space:]' < /root/tainted-node.txt 2>/dev/null)
[ -n "$TAINTED_NODE" ] || exit 1

kubectl get daemonset infra-agent >/dev/null 2>&1 || exit 1

DESIRED=""
READY=""
for i in $(seq 1 8); do
  DESIRED=$(kubectl get daemonset infra-agent -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)
  READY=$(kubectl get daemonset infra-agent -o jsonpath='{.status.numberReady}' 2>/dev/null)
  [ "$DESIRED" == "2" ] && [ "$READY" == "2" ] && break
  sleep 5
done
[ "$DESIRED" == "2" ] && [ "$READY" == "2" ] || exit 1

# specifically confirm a Pod landed on the tainted node
POD_NODES=$(kubectl get pod -l app=infra-agent -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' 2>/dev/null)
echo "$POD_NODES" | grep -qxF "$TAINTED_NODE"
