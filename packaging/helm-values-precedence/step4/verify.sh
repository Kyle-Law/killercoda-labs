#!/bin/bash

VALUES=$(helm get values podinfo-values4 2>/dev/null)
echo "$VALUES" | grep -q 'build: "42"' || exit 1

ENV_OK=0
for i in $(seq 1 12); do
  ENV=$(kubectl get pods -l app.kubernetes.io/name=podinfo-values4 -o jsonpath='{.items[0].spec.containers[0].env}' 2>/dev/null)
  echo "$ENV" | grep -q "fixed the widget" && { ENV_OK=1; break; }
  sleep 5
done
[ "$ENV_OK" -eq 1 ] || exit 1

HOST=$(kubectl get ingress podinfo-values4 -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)
[ "$HOST" == "api.example.com" ] || exit 1
