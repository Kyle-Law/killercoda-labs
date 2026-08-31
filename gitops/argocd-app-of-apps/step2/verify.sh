#!/bin/bash

for i in $(seq 1 30); do
  CHILD_APP=$(kubectl get application example.kustomize-guestbook -n argocd --ignore-not-found -o name 2>/dev/null)
  DEPLOY=$(kubectl -n kustomize-guestbook get deployment kustomize-guestbook-ui --ignore-not-found -o name 2>/dev/null)
  GUESTBOOK_OUT=$(argocd app get example.guestbook --core 2>/dev/null)
  if [ -z "$CHILD_APP" ] && [ -z "$DEPLOY" ] && echo "$GUESTBOOK_OUT" | grep -q "^Sync Status:.*Synced" && echo "$GUESTBOOK_OUT" | grep -q "^Health Status:.*Healthy"; then
    exit 0
  fi
  sleep 5
done

exit 1
