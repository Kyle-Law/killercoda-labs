#!/bin/bash
LOG=/root/.check
STEP="Step 4 · The rules you skipped"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

WORKER=$(cat /root/worker 2>/dev/null)

# How many events with this reason the kubelet has written. Events outlive the
# Pods they are about, which matters here: a Pod refused over a NoExecute taint
# is deleted within seconds, and its two events are all that is left of it.
kubelet_events() {
  kubectl get events -A --field-selector reason="$1" \
    -o jsonpath='{range .items[*]}{.source.component}{"\n"}{end}' 2>/dev/null \
    | grep -cx kubelet
}

[ "$(kubelet_events NodeAffinity)" -gt 0 ] || fail \
  "No Pod has been refused by the kubelet over its nodeSelector yet." \
  "" \
  "Put a Pod on the worker with spec.nodeName, with a nodeSelector the worker does" \
  "not satisfy (disktype: ssd will do), and look at what happens to it:" \
  "  kubectl get events -A --field-selector reason=NodeAffinity"

[ "$(kubelet_events TaintToleration)" -gt 0 ] || fail \
  "No Pod has been refused by the kubelet over a NoExecute taint yet." \
  "" \
  "Taint the worker NoExecute, then put a Pod on it with spec.nodeName that does" \
  "not tolerate the taint. The Pod will not stay long enough to inspect -- read" \
  "its events instead:" \
  "  kubectl get events -A --field-selector reason=TaintToleration" \
  "" \
  "A Pod that was already running there when you tainted the node is evicted by" \
  "the taint and never reaches the kubelet's check. Create a new Pod after the taint."

FILE=/root/answers/step4
[ -s "$FILE" ] || fail \
  "Both refusals happened. There is no answer in $FILE yet." \
  "" \
  "Of the three rules (a NoSchedule taint, a nodeSelector, a NoExecute taint) one" \
  "was not enforced by anything once the scheduler was skipped. Write which:" \
  "  echo <rule> > $FILE" \
  "" \
  "Look back at the first Pod you put on the worker: what became of it?"

ANS=$(tr 'A-Z' 'a-z' < "$FILE" | tr -cd 'a-z0-9')
HAS_NS=0; OTHERS=0
case "$ANS" in *noschedule*) HAS_NS=1 ;; esac
case "$ANS" in *noexecute*|*selector*|*affinity*) OTHERS=1 ;; esac

if [ "$HAS_NS" == 1 ] && [ "$OTHERS" == 1 ]; then
  fail \
    "Your answer names more than one rule: $(cat "$FILE")" \
    "" \
    "Name only the one that nothing enforced."
elif [ "$HAS_NS" != 1 ]; then
  case "$ANS" in
    *noexecute*) fail \
      "NoExecute was enforced -- twice." \
      "" \
      "  kubectl get events -A --field-selector reason=TaintToleration" \
      "  kubectl get events -A --field-selector reason=TaintManagerEviction" \
      "" \
      "Two different components said no. Look at the other two rules." ;;
    *selector*|*affinity*) fail \
      "The nodeSelector was enforced -- by the kubelet." \
      "" \
      "  kubectl get events -A --field-selector reason=NodeAffinity" \
      "" \
      "It left a Failed Pod behind saying so. Look at the other two rules." ;;
    *) fail \
      "'$(cat "$FILE")' does not name one of the three rules." \
      "" \
      "Write which of: NoSchedule, nodeSelector, NoExecute -- the one nothing enforced." ;;
  esac
fi

LEFT=$(kubectl get node "$WORKER" \
  -o jsonpath='{range .spec.taints[*]}{.key}={.value}:{.effect}{"\n"}{end}' 2>/dev/null \
  | grep -v '^node\.kubernetes\.io/')
[ -z "$LEFT" ] || fail \
  "The right answer -- but the worker still carries a taint of yours:" \
  "" \
  "$LEFT" \
  "" \
  "Remove it (the same arguments with a trailing '-'), for example:" \
  "  kubectl taint node $WORKER <key>=<value>:<effect>-"

pass
