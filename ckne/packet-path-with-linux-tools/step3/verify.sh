#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 3 · The address that isn't real"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

PODIP=$(kubectl get pod -l app=web --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].status.podIP}' 2>/dev/null)
CLUSTERIP=$(kubectl get svc web -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
[ -n "$PODIP" ] && [ -n "$CLUSTERIP" ] || fail \
  "Could not read the web Pod's address or the Service's ClusterIP." \
  "" \
  "  kubectl get pods -l app=web -o wide" \
  "  kubectl get svc web"

CAP=/root/cap-service.txt
EVIDENCE=/root/svc-translation.txt
[ -f "$CAP" ] || fail \
  "No capture at $CAP." \
  "" \
  "Capture on client's own veth while making a request through the Service:" \
  "  tcpdump -i \$(podveth client) -n -c 10 tcp > $CAP 2>&1 &"

[ -f "$EVIDENCE" ] || fail \
  "No evidence file at $EVIDENCE." \
  "" \
  "Once you know which datapath this cluster runs, save the place that datapath" \
  "keeps the translation -- the iptables rules for the Service, or the entry in" \
  "Cilium's service map:" \
  "  svctable web"

# The capture has to be on client's veth -- that is what makes the address in
# it meaningful either way.
CVETH=$(podveth client 2>/dev/null)
[ -n "$CVETH" ] || fail \
  "Could not work out which interface belongs to the client Pod." \
  "" \
  "  kubectl get pods -l app=client -o wide" \
  "  podveth client"

grep -q "listening on $CVETH," "$CAP" || fail \
  "$CAP was not captured on client's veth ($CVETH)." \
  "" \
  "Its first line says where it was taken:" \
  "  head -1 $CAP" \
  "" \
  "The address in the capture only means something if it was taken on the" \
  "client's own interface -- before anything on the host could have rewritten it."

# Which datapath is this cluster actually running? Decided from the cluster
# itself rather than from what the learner claims, so each branch below is
# checked against the thing that is really true here.
if iptables-save -t nat 2>/dev/null | grep -q "default/web"; then
  # kube-proxy: translation happens in the forwarding path, so a capture on
  # the client's own veth must still show the ClusterIP and never the Pod IP.
  grep -qE "IP [0-9.]+\.[0-9]+ > ${CLUSTERIP}\.80: .*HTTP: GET" "$CAP" || fail \
    "This cluster runs kube-proxy, but the capture does not show a GET to the ClusterIP ($CLUSTERIP:80)." \
    "" \
    "What the capture holds:" \
    "$(grep -E '^[0-9]{2}:' "$CAP" | head -4 | sed 's/^/  /')" \
    "" \
    "On this datapath the rewrite happens in the host's forwarding path, which is" \
    "strictly after the packet leaves client's veth -- so the capture must still" \
    "be addressed to the ClusterIP. Ask for the payload (-A) and request the" \
    "Service, not the Pod."

  grep -q "$PODIP" "$CAP" && fail \
    "The capture contains the Pod's address ($PODIP), which cannot happen on this datapath." \
    "" \
    "kube-proxy rewrites the destination in the host's forwarding path, after the" \
    "packet has left client's veth. The Pod IP appearing there means the request" \
    "was made straight to the Pod rather than through the Service -- redo it" \
    "against $CLUSTERIP."

  # ...and the saved evidence must be the real DNAT rule for this Service.
  grep -q "DNAT" "$EVIDENCE" || fail \
    "$EVIDENCE does not contain a DNAT rule." \
    "" \
    "On a kube-proxy cluster the translation lives in the nat table. Save the" \
    "rules for this Service, including the one that does the rewrite:" \
    "  iptables-save -t nat | grep 'default/web' | tee $EVIDENCE"

  grep -q "default/web" "$EVIDENCE" || fail \
    "$EVIDENCE does not mention the web Service." \
    "" \
    "kube-proxy comments every rule it writes with the Service it belongs to," \
    "which is how you find the right chain among hundreds:" \
    "  iptables-save -t nat | grep 'default/web' | tee $EVIDENCE"

  grep -q "$PODIP" "$EVIDENCE" || fail \
    "$EVIDENCE does not name the backend Pod's address ($PODIP)." \
    "" \
    "The chain that matters is the last one in the hop -- the per-endpoint chain" \
    "whose DNAT target is the Pod itself. Follow the chain names down until you" \
    "reach it:" \
    "  iptables-save -t nat | grep 'default/web' | tee $EVIDENCE"
else
  # eBPF socket LB: the rewrite happened inside connect(), before a packet
  # existed, so the wire shows the Pod IP and target port from the very first
  # SYN -- and the ClusterIP never appears on it at all.
  grep -qE "> ${PODIP}\.8080: " "$CAP" || fail \
    "This cluster runs eBPF socket load balancing, but the capture does not show traffic to ${PODIP}:8080." \
    "" \
    "What the capture holds:" \
    "$(grep -E '^[0-9]{2}:' "$CAP" | head -4 | sed 's/^/  /')" \
    "" \
    "Here the rewrite happens inside connect(), before a packet exists -- so the" \
    "first SYN on the wire is already addressed to the Pod and its target port." \
    "Make the request through the Service and capture on client's veth:" \
    "  kubectl exec client -- wget -qO- -T5 http://$CLUSTERIP/hostname"

  grep -q "$CLUSTERIP" "$CAP" && fail \
    "The ClusterIP ($CLUSTERIP) appears in the capture, which cannot happen on this datapath." \
    "" \
    "With socket load balancing there is no in-flight translation to see: the" \
    "address was rewritten before the kernel built a packet. A ClusterIP on the" \
    "wire means the capture is from somewhere else, or from before this cluster's" \
    "datapath was in play. Retake it:" \
    "  tcpdump -i $CVETH -n -c 10 tcp > $CAP 2>&1 &"

  # The evidence has to come from the map, and name both ends of the mapping.
  grep -q "$CLUSTERIP" "$EVIDENCE" || fail \
    "$EVIDENCE does not name the ClusterIP ($CLUSTERIP)." \
    "" \
    "iptables-save is empty on this datapath -- the mapping lives in an eBPF map" \
    "instead, and holds exactly what the iptables chain would have:" \
    "  kubectl -n kube-system exec ds/cilium -c cilium-agent -- \\" \
    "    cilium-dbg service list | grep -E \"Frontend|$CLUSTERIP\" | tee $EVIDENCE"

  grep -q "$PODIP" "$EVIDENCE" || fail \
    "$EVIDENCE names the ClusterIP but not the backend ($PODIP)." \
    "" \
    "The useful half of that entry is the right-hand side: which Pod and port the" \
    "frontend actually maps to. Keep the whole line:" \
    "  kubectl -n kube-system exec ds/cilium -c cilium-agent -- \\" \
    "    cilium-dbg service list | grep -E \"Frontend|$CLUSTERIP\" | tee $EVIDENCE"
fi

pass
