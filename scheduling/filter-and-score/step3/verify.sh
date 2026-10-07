#!/bin/bash
LOG=/root/.check
STEP="Step 3 · A preference is a vote with a price"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

# The taint is part of the problem. Removing it is not a fix.
kubectl get node kwok-node-5 -o jsonpath='{range .spec.taints[*]}{.effect}{"\n"}{end}' 2>/dev/null \
  | grep -q PreferNoSchedule || fail \
  "kwok-node-5 no longer carries a PreferNoSchedule taint." \
  "" \
  "The task was to get the Pods onto it WITH the taint still there:" \
  "  kubectl taint node kwok-node-5 soft=yes:PreferNoSchedule"

kubectl get deployment seekers >/dev/null 2>&1 || fail \
  "There is no Deployment called 'seekers'." \
  "" \
  "  kubectl apply -f /root/seekers.yaml"

# The preference has to be what it was: preferred, weight 100, not turned into a requirement.
W=$(kubectl get deployment seekers -o jsonpath='{.spec.template.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution[0].weight}' 2>/dev/null)
REQ=$(kubectl get deployment seekers -o jsonpath='{.spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution}' 2>/dev/null)
[ "$W" == "100" ] && [ -z "$REQ" ] || fail \
  "The preference on 'seekers' has changed (weight: ${W:-<none>}, required: ${REQ:-<none>})." \
  "" \
  "It should still be a preferred term with weight 100. Making it required, or changing its weight," \
  "is not the fix: the question is what is outvoting it."

# Wait for six Pods, then see where they went.
for _ in $(seq 1 12); do
  RUN=$(kubectl get pods -l app=seekers --no-headers 2>/dev/null | awk '$3=="Running"' | wc -l)
  [ "$RUN" -ge 6 ] && break
  sleep 3
done
ONGOLD=$(kubectl get pods -l app=seekers -o go-template='{{range .items}}{{if not .metadata.deletionTimestamp}}{{.spec.nodeName}}{{"\n"}}{{end}}{{end}}' 2>/dev/null | grep -c '^kwok-node-5$')

[ "$ONGOLD" -ge 6 ] || fail \
  "$ONGOLD of the 6 'seekers' Pods are on kwok-node-5." \
  "" \
  "  kubectl get pods -l app=seekers -o wide" \
  "" \
  "Pods that are already placed never move, so a change to the Deployment's template has to" \
  "replace them. And the scheduler will tell you what is deciding, for any one of them:" \
  "  scores <pod> kwok-node-5     (compare it with any other node)"

FILE=/root/answers/step3
[ -s "$FILE" ] || fail \
  "All six are on kwok-node-5. There is no answer in $FILE yet." \
  "" \
  "Which plugin outvoted a weight-100 preference, and what were the two numbers?" \
  "  echo \"plugin=<name> gain=<what the preference was worth> cost=<what the taint cost>\" > $FILE" \
  "" \
  "  scores <a Pod from before the fix> kwok-node-5"

PLUGIN=$(tr 'A-Z' 'a-z' < "$FILE")
echo "$PLUGIN" | grep -q 'tainttoleration' || fail \
  "The plugin you named is not the one that outvoted the preference." \
  "" \
  "  you wrote: $(head -c 80 "$FILE")" \
  "" \
  "Find the two plugins whose scores on kwok-node-5 differ most from the other nodes', and which" \
  "way each points. One is the preference. The other is what beat it."

GAIN=$(grep -oiE 'gain[^0-9]*[0-9]+' "$FILE" | head -1 | grep -oE '[0-9]+$')
COST=$(grep -oiE 'cost[^0-9]*[0-9]+' "$FILE" | head -1 | grep -oE '[0-9]+$')
[ -n "$GAIN" ] && [ -n "$COST" ] || fail \
  "Could not read gain and cost out of $FILE (it says: $(head -c 80 "$FILE"))." \
  "" \
  "Write it as:  echo \"plugin=<name> gain=<n> cost=<n>\" > $FILE"

[ "$GAIN" == "200" ] && [ "$COST" == "300" ] || fail \
  "The numbers do not match what the scheduler scored (you wrote gain=$GAIN cost=$COST)." \
  "" \
  "Read them off a Pod that was placed WITHOUT the toleration, node by node:" \
  "  scores <pod> kwok-node-5      and      scores <pod> kwok-node-0" \
  "gain is what NodeAffinity added to the gold node, cost is what TaintToleration took from it," \
  "as logged. Scores are already weighted."

pass
