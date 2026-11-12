#!/bin/bash
#
# Killercoda only reads the exit code, so every exit path writes its reason to
# /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 3 · It scales"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

TYPE=$(kubectl -n serve get hpa chat -o jsonpath='{.spec.metrics[0].type}' 2>/dev/null)
[ "$TYPE" == "Pods" ] || fail \
  "The HPA 'chat' is not on a Pods metric (it is '${TYPE:-missing}')." \
  "" \
  "Step 2's queue-based HPA has to be in place for this step:" \
  "  kubectl apply -f /root/hpa-queue.yaml"

# The rescale event names the metric that drove it, so a CPU-driven scale-up
# from earlier cannot pass this check by accident.
UP=$(kubectl -n serve get events --field-selector involvedObject.kind=HorizontalPodAutoscaler,reason=SuccessfulRescale \
  -o jsonpath='{range .items[*]}{.message}{"\n"}{end}' 2>/dev/null \
  | grep 'num_requests_waiting above target')
[ -n "$UP" ] || fail \
  "There is no record of the HPA scaling up on the queue metric." \
  "" \
  "Put load on and give it a minute:" \
  "  llmload 2 90" \
  "  kubectl get hpa chat -w" \
  "" \
  "Every rescale is an event on the HPA; the check looks for one whose reason" \
  "names the queue metric:" \
  "  kubectl get events --field-selector involvedObject.kind=HorizontalPodAutoscaler"

pass
