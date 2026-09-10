#!/bin/bash

# The log plugin has to be in the live ConfigMap, not just in /root/Corefile.
COREFILE=$(kubectl -n kube-system get cm coredns -o jsonpath='{.data.Corefile}' 2>/dev/null)
echo "$COREFILE" | grep -qE '^\s*log(\s|$)' || exit 1

# And CoreDNS has to be actually running it -- an applied-but-not-yet-reloaded
# config would leave the learner looking at an empty log wondering why.
for _ in $(seq 1 30); do
  kubectl exec dnstools -- dig +short web.default.svc.cluster.local >/dev/null 2>&1

  LOGS=$(kubectl -n kube-system logs -l k8s-app=kube-dns --tail=-1 2>/dev/null)
  echo "$LOGS" | grep -q '"A IN web.default.svc.cluster.local' && exit 0

  sleep 5
done

exit 1
