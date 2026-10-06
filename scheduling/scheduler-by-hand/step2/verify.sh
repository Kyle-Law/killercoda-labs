#!/bin/bash
LOG=/root/.check
STEP="Step 2 · Be the scheduler once"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

# --- batch-1: bound and running, and still the Pod it started as -------------
UIDNOW=$(kubectl get pod batch-1 -o jsonpath='{.metadata.uid}' 2>/dev/null)
[ -n "$UIDNOW" ] || fail \
  "There is no Pod called 'batch-1' any more." \
  "" \
  "The task is to place the one you were given, not to replace it:" \
  "  kubectl get pods"

[ "$UIDNOW" == "$(cat /root/.batch-1.uid 2>/dev/null)" ] || fail \
  "batch-1 exists, but it is not the Pod you started with." \
  "" \
  "It was deleted and recreated. A Pod's node is written once, by a Binding --" \
  "and the Pod you were given is the one that needs one."

R=""
for _ in $(seq 1 12); do
  NODE=$(kubectl get pod batch-1 -o jsonpath='{.spec.nodeName}' 2>/dev/null)
  [ -n "$NODE" ] || { R="unbound"; sleep 5; continue; }
  PHASE=$(kubectl get pod batch-1 -o jsonpath='{.status.phase}' 2>/dev/null)
  [ "$PHASE" == "Running" ] || { R="notrunning"; sleep 5; continue; }
  R=""; break
done

case "$R" in
  unbound) fail \
    "batch-1 still has no node." \
    "" \
    "  kubectl get pod batch-1 -o jsonpath='{.spec.nodeName}'" \
    "" \
    "Nothing is going to place it: its schedulerName is 'nightly-batch' and no one" \
    "runs that. A node is written onto a Pod by a Binding -- see 'kubectl explain binding'." ;;
  notrunning) fail \
    "batch-1 has a node ($NODE) but is not Running (phase: ${PHASE:-<none>})." \
    "" \
    "  kubectl describe pod batch-1" \
    "" \
    "Give it a few seconds if the image is still being pulled, then press CHECK again." ;;
esac

# --- ghost: bound to nowhere, and what became of it --------------------------
if kubectl get pod ghost >/dev/null 2>&1; then
  GNODE=$(kubectl get pod ghost -o jsonpath='{.spec.nodeName}' 2>/dev/null)
  if [ -z "$GNODE" ]; then
    fail \
      "batch-1 is placed. 'ghost' exists, but it has not been bound to anything." \
      "" \
      "Bind it to a node called 'nowhere' -- the same Binding you used for batch-1," \
      "with a node name that does not exist -- and see what the API says."
  elif [ "$GNODE" == "nowhere" ]; then
    fail \
      "batch-1 is placed. 'ghost' is still here, bound to a node called 'nowhere'." \
      "" \
      "  kubectl get pod ghost -o wide" \
      "" \
      "Something cleans up Pods bound to a node that does not exist, but not at once." \
      "Wait about a minute, watch 'kubectl get pod ghost', and press CHECK again."
  else
    fail \
      "'ghost' is bound to '$GNODE', which is a real node." \
      "" \
      "The task was a node that does not exist. Delete it and try again:" \
      "  kubectl delete pod ghost --now" \
      "  kubectl apply -f /root/ghost.yaml" \
      "and bind it to a node named 'nowhere'."
  fi
fi

[ -s /root/answers/step2 ] || fail \
  "batch-1 is placed, and 'ghost' is gone. One thing left." \
  "" \
  "Write one word for what became of 'ghost' into /root/answers/step2:" \
  "  echo <word> > /root/answers/step2" \
  "" \
  "If you never created it, create it, bind it to 'nowhere', and watch:" \
  "  kubectl apply -f /root/ghost.yaml"

pass
