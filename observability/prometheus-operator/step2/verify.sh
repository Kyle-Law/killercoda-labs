#!/bin/bash

kubectl get serviceaccount prometheus >/dev/null 2>&1 || exit 1

SA="system:serviceaccount:default:prometheus"

# RBAC can take a moment to propagate - retry rather than require sustained success
for i in $(seq 1 4); do
  OK=1
  kubectl auth can-i list pods --as="$SA" --all-namespaces 2>/dev/null | grep -q "^yes$" || OK=0
  kubectl auth can-i list nodes --as="$SA" 2>/dev/null | grep -q "^yes$" || OK=0
  kubectl auth can-i list endpoints --as="$SA" --all-namespaces 2>/dev/null | grep -q "^yes$" || OK=0
  kubectl auth can-i list services --as="$SA" --all-namespaces 2>/dev/null | grep -q "^yes$" || OK=0
  [ "$OK" == "1" ] && exit 0
  sleep 2
done

exit 1
