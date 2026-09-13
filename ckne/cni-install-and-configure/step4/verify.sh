#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 4 · Turn on what the rest of the exam needs"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

# kube-proxy must be gone, and -- the part people skip -- its rules with it.
kubectl -n kube-system get ds kube-proxy >/dev/null 2>&1 && fail \
  "The kube-proxy DaemonSet is still there." \
  "" \
  "Replacing kube-proxy means removing it, not merely turning Cilium's" \
  "replacement on beside it:" \
  "  kubectl -n kube-system delete ds kube-proxy"

LEFT=$(iptables-save -t nat 2>/dev/null | grep -c KUBE)
[ "$LEFT" == "0" ] || fail \
  "kube-proxy is gone but $LEFT of its iptables rules are still in the nat table." \
  "" \
  "Deleting the DaemonSet does not unwind what it wrote -- the chains stay until" \
  "something removes them, and they keep answering for Services:" \
  "  iptables-save -t nat | grep KUBE | head" \
  "  kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg cleanup --help"

# The policy demonstration has to be cleaned up, or the Service check below
# would be measuring the policy rather than the datapath.
kubectl get netpol deny-all-to-web >/dev/null 2>&1 && fail \
  "The 'deny-all-to-web' policy from step 2 is still in force." \
  "" \
  "The check below has to reach web through its Service; with that policy on, a" \
  "failure would mean the policy worked, not that the datapath did:" \
  "  kubectl delete netpol deny-all-to-web"

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

  echo "$RESULT" | grep -q "^web-" && pass
  sleep 5
done

echo "$STATUS" | grep -q "KubeProxyReplacement:.*True" && KPR="True" || KPR="not True"
echo "$STATUS" | grep -q "Hubble:.*Ok" && HUB="Ok" || HUB="not Ok"
fail \
  "kube-proxy is gone, but Cilium is not yet doing its job in its place." \
  "" \
  "  KubeProxyReplacement:  $KPR" \
  "  Hubble:                $HUB" \
  "  web ClusterIP:         ${CLUSTER_IP:-<none>}" \
  "  request through it:    ${RESULT:-<no answer>}" \
  "" \
  "Both features are Helm values, and changing them needs the agent restarted" \
  "before it re-reads its configuration:" \
  "  kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status | head -20" \
  "  kubectl -n kube-system rollout restart ds/cilium" \
  "" \
  "kubeProxyReplacement also needs the API server's address given explicitly --" \
  "with kube-proxy deleted there is nothing left to resolve the kubernetes" \
  "Service for the agent itself."
