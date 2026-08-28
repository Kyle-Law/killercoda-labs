#!/bin/bash

# the chart must exist on disk and keep index.html as a real file
[ -f /root/charts/site/Chart.yaml ] || exit 1
[ -f /root/charts/site/files/index.html ] || exit 1

# and be a valid chart, not just files in the right shape
helm lint /root/charts/site >/dev/null 2>&1 || exit 1

# the release must be installed from that chart
helm status dev >/dev/null 2>&1 || exit 1

# resources must be named after the release, so a second release can coexist
kubectl get deployment dev-site >/dev/null 2>&1 || exit 1

TYPE=$(kubectl get svc dev-site -o jsonpath='{.spec.type}' 2>/dev/null)
[ "$TYPE" == "NodePort" ] || exit 1

for i in $(seq 1 18); do
  curl -s --max-time 5 http://localhost:30080 2>/dev/null | grep -q "Served by nginx" && exit 0
  sleep 5
done

exit 1
