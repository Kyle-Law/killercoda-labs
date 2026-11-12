#!/bin/bash

echo -n "Preparing the cluster (Prometheus, prometheus-adapter, metrics-server: a few minutes)..."
while [ ! -f /tmp/.initfinished ]; do echo -n '.'; sleep 2; done
echo " done"

if [ -f /tmp/.initbroken ]; then
  echo
  echo "!! Something did not come up: the model server, Prometheus, or the adapter's"
  echo "!! custom metrics. Steps 2 to 4 depend on all three."
  echo "!! Check with:  kubectl get pods -A ; kubectl get apiservice | grep metrics"
fi
echo
