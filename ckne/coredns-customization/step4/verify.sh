#!/bin/bash

# The stored config has to be valid again -- leaving the typo in place is the
# whole hazard this step is about, and DNS answering is not evidence that it
# is gone.
COREFILE=$(kubectl -n kube-system get cm coredns -o jsonpath='{.data.Corefile}' 2>/dev/null)
echo "$COREFILE" | grep -q "forwardd" && exit 1
echo "$COREFILE" | grep -qE '^\s*forward\s+\.' || exit 1

CLUSTER_IP=$(kubectl get svc web -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
[ -n "$CLUSTER_IP" ] || exit 1

# A healthy cluster with a valid Corefile is also the state this step *starts*
# in, so that alone would pass without the step being done. The evidence that
# it was done is a CoreDNS Pod that crashed on the broken config and recovered:
# restart counts it could not have had beforehand.
RESTARTED=$(kubectl -n kube-system get pods -l k8s-app=kube-dns \
  -o jsonpath='{range .items[*]}{.status.containerStatuses[*].restartCount}{"\n"}{end}' 2>/dev/null \
  | awk '$1 > 0' | wc -l)
[ "$RESTARTED" -ge 1 ] || exit 1

for _ in $(seq 1 36); do
  # Every CoreDNS Pod must actually be able to start on the stored config.
  DESIRED=$(kubectl -n kube-system get deploy coredns -o jsonpath='{.spec.replicas}' 2>/dev/null)
  READY=$(kubectl -n kube-system get deploy coredns -o jsonpath='{.status.readyReplicas}' 2>/dev/null)

  if [ -n "$DESIRED" ] && [ "$DESIRED" == "$READY" ]; then
    NOTRUNNING=$(kubectl -n kube-system get pods -l k8s-app=kube-dns \
      -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null | grep -cv '^Running$')

    if [ "$NOTRUNNING" == "0" ]; then
      # And the work from the earlier steps must have survived the recovery.
      WEB=$(kubectl exec dnstools -- dig +short web.default.svc.cluster.local 2>/dev/null | tr -d '[:space:]')
      DB=$(kubectl exec dnstools -- dig +short db.corp.internal 2>/dev/null | tr -d '[:space:]')
      LEGACY=$(kubectl exec dnstools -- dig +short legacy-api.example.com 2>/dev/null | tr -d '[:space:]')

      [ "$WEB" == "$CLUSTER_IP" ] && [ "$DB" == "10.99.0.42" ] && [ "$LEGACY" == "$CLUSTER_IP" ] && exit 0
    fi
  fi
  sleep 5
done

exit 1
