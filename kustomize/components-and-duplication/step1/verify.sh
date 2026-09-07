#!/bin/bash

# both environments must carry the new port - missing one is exactly the
# drift this step is about
for e in staging prod; do
  R=$(kubectl kustomize /root/app/overlays/$e 2>/dev/null)
  [ -n "$R" ] || exit 1
  echo "$R" | grep -q 'prometheus.io/port: "9102"' || exit 1
  echo "$R" | grep -q '9090' && exit 1
done

exit 0
