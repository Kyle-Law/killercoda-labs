#!/bin/bash

# kube-proxy must be gone, and -- the part people skip -- its rules with it.
kubectl -n kube-system get ds kube-proxy >/dev/null 2>&1 && exit 1
[ "$(iptables-save -t nat 2>/dev/null | grep -c KUBE)" == "0" ] || exit 1

# The policy demonstration has to be cleaned up, or the Service check below
# would be measuring the policy rather than the datapath.
kubectl get netpol deny-all-to-web >/dev/null 2>&1 && exit 1

for _ in $(seq 1 24); do
  STATUS=$(kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status 2>/dev/null)

  echo "$STATUS" | grep -q "KubeProxyReplacement:.*True" || { sleep 5; continue; }
  echo "$STATUS" | grep -q "Hubble:.*Ok" || { sleep 5; continue; }

  # Cilium is serving the Service from its own map, not from leftover rules.
  CLUSTER_IP=$(kubectl get svc web -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
  [ -n "$CLUSTER_IP" ] || { sleep 5; continue; }
  kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg service list 2>/dev/null \
    | grep -q "$CLUSTER_IP" || { sleep 5; continue; }

  # And it genuinely carries traffic with every kube-proxy rule removed.
  kubectl delete pod svcverify --ignore-not-found --wait=true >/dev/null 2>&1
  kubectl run svcverify --restart=Never --image=registry.k8s.io/e2e-test-images/agnhost:2.53 \
    --command -- /bin/sh -c 'wget -qO- -T5 http://web/hostname' >/dev/null 2>&1
  kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/svcverify --timeout=60s >/dev/null 2>&1
  RESULT=$(kubectl logs svcverify 2>/dev/null)
  kubectl delete pod svcverify --wait=false >/dev/null 2>&1

  echo "$RESULT" | grep -q "^web-" && exit 0
  sleep 5
done

exit 1
