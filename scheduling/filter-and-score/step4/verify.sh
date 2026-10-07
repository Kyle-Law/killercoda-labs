#!/bin/bash
LOG=/root/.check
STEP="Step 4 · The nodes nobody looked at"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

FAKE=$(kubectl get nodes -l type=kwok --no-headers 2>/dev/null | wc -l)
[ "$FAKE" -ge 200 ] || fail \
  "There are only $FAKE fake nodes. Sampling does not start until there are more than 100 nodes, and" \
  "this step is about what happens well above that." \
  "" \
  "  reset-nodes 250        (takes about a minute; leave it at 250 until this check passes)"

TAINTED=$(kubectl get nodes -l type=kwok -o jsonpath='{range .items[*]}{range .spec.taints[*]}{.key}{"\n"}{end}{end}' 2>/dev/null | grep -c 'node.kubernetes.io/not-ready')
[ "$TAINTED" -eq 0 ] || fail \
  "$TAINTED of the fake nodes still carry a not-ready taint, so they are not candidates for anything yet." \
  "" \
  "They clear at about five a second. Wait, and press CHECK again:" \
  "  kubectl get nodes -o jsonpath='{range .items[*]}{range .spec.taints[*]}{.key}{\"\\n\"}{end}{end}' | grep -c not-ready"

CZ=$(curl -sk --cert /root/.configz.crt --key /root/.configz.key https://127.0.0.1:10259/configz 2>/dev/null)
[ -n "$CZ" ] || fail \
  "The scheduler is not answering on 127.0.0.1:10259." \
  "" \
  "  kubectl -n kube-system get pods -l component=kube-scheduler" \
  "  kubectl -n kube-system logs -l component=kube-scheduler --tail=20"

# What the number should have been BEFORE the fix, from the cluster's own node count and the
# scheduler's formula: 50 - nodes/125 percent, at least 5, of all nodes, at least 100.
N=$(kubectl get nodes --no-headers | wc -l)
PCT=$((50 - N / 125)); [ "$PCT" -lt 5 ] && PCT=5
WANT=$((N * PCT / 100)); [ "$WANT" -lt 100 ] && WANT=100

FILE=/root/answers/step4
[ -s "$FILE" ] || fail \
  "There is no answer in $FILE yet." \
  "" \
  "How many nodes did the scheduler find feasible for the 'seekers20' Pods, before you changed anything?" \
  "  echo \"feasible=<n>\" > $FILE" \
  "" \
  "It is on the bind line, which is V(2):" \
  "  kubectl -n kube-system logs -l component=kube-scheduler --tail=-1 | grep 'Successfully bound' | grep seekers20 | head -3"

ANS=$(grep -oiE 'feasible[^0-9]*[0-9]+' "$FILE" | head -1 | grep -oE '[0-9]+$')
[ -n "$ANS" ] || fail \
  "Could not read a number out of $FILE (it says: $(head -c 80 "$FILE"))." \
  "" \
  "Write it as:  echo \"feasible=<n>\" > $FILE"

if [ "$ANS" == "$N" ] || [ "$ANS" == "$((N - 1))" ]; then
  fail \
    "$ANS is every node in the cluster. That is what the scheduler finds once the fix is in, not before." \
    "" \
    "What did the log say for the Pods placed BEFORE you changed the setting? Those lines are" \
    "still in the scheduler's log, from the first run."
fi
[ "$ANS" == "$WANT" ] || fail \
  "The number you wrote ($ANS) is not what the scheduler found feasible with $N nodes and the default setting." \
  "" \
  "  kubectl -n kube-system logs -l component=kube-scheduler --tail=-1 | grep 'Successfully bound' | grep seekers20 | head -3" \
  "" \
  "If you cannot see those lines, the scheduler is not logging at V(2): --vmodule=schedule_one=2."

PCTRUN=$(echo "$CZ" | grep -o '"percentageOfNodesToScore":[0-9]*' | cut -d: -f2)
[ "$PCTRUN" == "100" ] || fail \
  "Your number is right. The scheduler is still sampling: its running percentageOfNodesToScore is ${PCTRUN:-<unset>}." \
  "" \
  "  configz | grep -o '\"percentageOfNodesToScore\":[0-9]*'" \
  "" \
  "It is a setting in /etc/kubernetes/scheduler-config.yaml, read only when the scheduler starts:" \
  "  restart-scheduler"

kubectl get deployment seekers20 >/dev/null 2>&1 || fail \
  "There is no Deployment called 'seekers20'." \
  "" \
  "  kubectl apply -f /root/seekers20.yaml"

for _ in $(seq 1 12); do
  RUN=$(kubectl get pods -l app=seekers20 --no-headers 2>/dev/null | awk '$3=="Running"' | wc -l)
  [ "$RUN" -ge 20 ] && break
  sleep 3
done
GOLD=$(kubectl get pods -l app=seekers20 -o go-template='{{range .items}}{{if not .metadata.deletionTimestamp}}{{.spec.nodeName}}{{"\n"}}{{end}}{{end}}' 2>/dev/null | grep -c '^kwok-node-5$')
[ "$GOLD" -ge 14 ] || fail \
  "The scheduler is now looking at every node, but only $GOLD of the 20 'seekers20' Pods are on kwok-node-5." \
  "" \
  "  kubectl get pods -l app=seekers20 -o wide" \
  "" \
  "Pods that were placed before the change never move. Delete the Deployment and apply it again:" \
  "  kubectl delete -f /root/seekers20.yaml && kubectl apply -f /root/seekers20.yaml"

pass
