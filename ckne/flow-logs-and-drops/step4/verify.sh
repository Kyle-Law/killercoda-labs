#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 4 · An allow-list derived from real traffic"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

# The policy must exist, select api, and permit web on the container port.
POL=$(kubectl get netpol api-allow-web -o json 2>/dev/null)
[ -n "$POL" ] || fail \
  "There is no NetworkPolicy named 'api-allow-web'." \
  "" \
  "It needs to select api, allow ingress from web, and name the port the" \
  "traffic actually arrives on. Every field is visible in the flow log:" \
  "  flows --since 30s --to-pod api --from-pod web | head -2"

echo "$POL" | grep -q '"app": *"api"' || fail \
  "'api-allow-web' does not select app=api." \
  "" \
  "Its podSelector decides what the policy protects, and that has to be api:" \
  "  kubectl get netpol api-allow-web -o yaml"

echo "$POL" | grep -q '"app": *"web"' || fail \
  "'api-allow-web' does not allow app=web." \
  "" \
  "Without an ingress rule naming web, the policy is a default-deny with extra" \
  "steps -- it will block the legitimate caller too:" \
  "  kubectl get netpol api-allow-web -o yaml"

echo "$POL" | grep -q '8080' || fail \
  "'api-allow-web' does not name port 8080." \
  "" \
  "Look at the port on the DESTINATION side of the arrow in a flow -- a policy" \
  "matches the container's port, not the Service's:" \
  "  flows --since 30s --to-pod api --from-pod web | head -2"

# A leftover blanket deny would make the "blocked" half true for the wrong
# reason, so the tight policy has to be the one in force.
kubectl get netpol api-deny >/dev/null 2>&1 && fail \
  "'api-deny' is back, or was never deleted." \
  "" \
  "Policies are additive but a deny-all leaves nothing for your allow rule to" \
  "prove: the scanner would be refused by the blanket policy rather than by the" \
  "one you wrote. Remove it so api-allow-web is the only thing in force:" \
  "  kubectl delete netpol api-deny"

# Now prove it from the flow log, scoped to after the change: web forwarded,
# scanner dropped. Retried because both sides poll on their own timers.
for _ in $(seq 1 18); do
  FWD=$(kubectl -n kube-system exec ds/cilium -c cilium-agent -- \
    hubble observe --since 25s --to-pod api --verdict FORWARDED 2>/dev/null)
  DROP=$(kubectl -n kube-system exec ds/cilium -c cilium-agent -- \
    hubble observe --since 25s --to-pod api --verdict DROPPED 2>/dev/null)

  echo "$FWD" | grep -q "default/web" || { sleep 5; continue; }
  echo "$DROP" | grep -q "default/scanner" || { sleep 5; continue; }
  # ...and the scanner must NOT be getting through any more.
  echo "$FWD" | grep -q "default/scanner" && { sleep 5; continue; }
  pass
done

echo "$FWD" | grep -q "default/web"     && W="yes" || W="no"
echo "$DROP" | grep -q "default/scanner" && S="yes" || S="no"
echo "$FWD" | grep -q "default/scanner" && L="yes" || L="no"

fail \
  "The policy looks right, but the flow log does not yet show it working." \
  "" \
  "  web forwarded to api:      $W" \
  "  scanner dropped:           $S" \
  "  scanner still forwarded:   $L" \
  "" \
  "web 'no' means your ingress rule is not matching the real caller -- compare" \
  "its labels against the rule:" \
  "  kubectl get pod -l app=web --show-labels" \
  "" \
  "scanner 'no' on both lines usually means it simply has not tried in the last" \
  "25 seconds; press CHECK again." \
  "" \
  "scanner still forwarded means something else is still allowing it -- list" \
  "every policy that selects api, not just yours:" \
  "  kubectl get netpol"
