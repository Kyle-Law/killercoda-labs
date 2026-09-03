#!/bin/bash

kubectl get deployment web >/dev/null 2>&1 || exit 1

REPLICAS=$(kubectl get deployment web -o jsonpath='{.spec.replicas}' 2>/dev/null)
[ "$REPLICAS" == "3" ] || exit 1

for i in $(seq 1 24); do
  # Exactly one of the three Pods should be failing readiness.
  NOT_READY=$(kubectl get pods -l app=web \
    -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}' 2>/dev/null | grep -c "false")

  # ...and nothing should have been restarted -- readiness never kills.
  TOTAL_RESTARTS=$(kubectl get pods -l app=web \
    -o jsonpath='{range .items[*]}{.status.containerStatuses[0].restartCount}{"\n"}{end}' 2>/dev/null \
    | awk '{s+=$1} END {print s+0}')

  # All three Pods must still be Running -- removed from traffic, not killed.
  RUNNING=$(kubectl get pods -l app=web \
    -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null | grep -c "Running")

  # The Service must be down to exactly two serving endpoints.
  READY_EPS=$(kubectl get endpointslice -l kubernetes.io/service-name=web \
    -o jsonpath='{range .items[*].endpoints[*]}{.conditions.ready}{"\n"}{end}' 2>/dev/null | grep -c "true")

  if [ "$NOT_READY" == "1" ] && [ "$TOTAL_RESTARTS" == "0" ] \
     && [ "$RUNNING" == "3" ] && [ "$READY_EPS" == "2" ]; then
    exit 0
  fi
  sleep 5
done

exit 1
