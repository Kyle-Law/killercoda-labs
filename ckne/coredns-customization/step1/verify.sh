#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 1 · Make the Corefile tell you what it's doing"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

# The log plugin has to be in the live ConfigMap, not just in /root/Corefile.
COREFILE=$(kubectl -n kube-system get cm coredns -o jsonpath='{.data.Corefile}' 2>/dev/null)
[ -n "$COREFILE" ] || fail \
  "Could not read the 'coredns' ConfigMap in kube-system." \
  "" \
  "  kubectl -n kube-system get cm coredns -o yaml"

echo "$COREFILE" | grep -qE '^\s*log(\s|$)' || fail \
  "The live Corefile has no 'log' plugin in it." \
  "" \
  "Editing a copy on disk changes nothing -- CoreDNS reads the ConfigMap. Put" \
  "the plugin in the server block and apply it there:" \
  "  kubectl -n kube-system edit cm coredns" \
  "" \
  "The Corefile currently in force:" \
  "$(echo "$COREFILE" | sed 's/^/  /' | head -20)"

# And CoreDNS has to be actually running it -- an applied-but-not-yet-reloaded
# config would leave the learner looking at an empty log wondering why.
for _ in $(seq 1 30); do
  kubectl exec dnstools -- dig +short web.default.svc.cluster.local >/dev/null 2>&1

  LOGS=$(kubectl -n kube-system logs -l k8s-app=kube-dns --tail=-1 2>/dev/null)
  echo "$LOGS" | grep -q '"A IN web.default.svc.cluster.local' && pass

  sleep 5
done

fail \
  "'log' is in the ConfigMap, but no query has appeared in CoreDNS's output." \
  "" \
  "The ConfigMap is mounted as a file, and the kubelet takes up to a minute to" \
  "push a change into the Pod -- then the reload plugin has to notice it. If it" \
  "stays empty for longer than that, look for a reload error:" \
  "  kubectl -n kube-system logs -l k8s-app=kube-dns --tail=30" \
  "" \
  "A config CoreDNS could not parse is kept running from the old one, so DNS" \
  "keeps working and nothing appears to be wrong."
