#!/bin/bash

kubectl get servicemonitor sample-app >/dev/null 2>&1 || exit 1

SEL=$(kubectl get servicemonitor sample-app -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null)
[ "$SEL" == "sample-app" ] || exit 1

# query Prometheus from inside the cluster rather than relying on a
# port-forward the learner may not have left running
for i in $(seq 1 30); do
  UP_COUNT=$(kubectl run prom-check-$RANDOM --rm -i --restart=Never --image=curlimages/curl:8.5.0 --command -- \
    curl -s --max-time 10 "http://prometheus-operated.default.svc.cluster.local:9090/api/v1/targets?state=active" 2>/dev/null \
    | grep -o '"health":"up"' | wc -l)
  [ "$UP_COUNT" -ge 2 ] 2>/dev/null && exit 0
  sleep 10
done

exit 1
