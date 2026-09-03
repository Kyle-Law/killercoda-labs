#!/bin/bash

kubectl get resourceflavor default-flavor >/dev/null 2>&1 || exit 1

# quota must actually be set on the GPU resource, not just the object existing
QUOTA=$(kubectl get clusterqueue gpu-queue \
  -o jsonpath='{.spec.resourceGroups[0].flavors[0].resources[?(@.name=="nvidia.com/gpu")].nominalQuota}' 2>/dev/null)
[ "$QUOTA" == "4" ] || exit 1

# the LocalQueue must point at that ClusterQueue, or jobs would never be admitted
CQ=$(kubectl get localqueue team-queue -n default -o jsonpath='{.spec.clusterQueue}' 2>/dev/null)
[ "$CQ" == "gpu-queue" ] || exit 1

exit 0
