#!/bin/bash
#
# Killercoda only reads the exit code, so every exit path writes its reason to
# /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 5 · The replica the average hides"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

MIN=$(kubectl -n serve get hpa chat -o jsonpath='{.spec.minReplicas}' 2>/dev/null)
MAX=$(kubectl -n serve get hpa chat -o jsonpath='{.spec.maxReplicas}' 2>/dev/null)
[ "${MIN:-0}" -ge 5 ] && [ "${MAX:-0}" -gt "${MIN:-0}" ] 2>/dev/null || fail \
  "The HPA's range is ${MIN:-?} to ${MAX:-?} replicas; this step wants at least 5, with room above." \
  "" \
  "  kubectl patch hpa chat -p '{\"spec\":{\"minReplicas\":5,\"maxReplicas\":10}}'"

FLOOD=$(awk '{for(i=1;i<=NF;i++) if($i ~ /^replicas=/){split($i,a,"="); if(a[2]+0>=5) print}}' /root/floods.log 2>/dev/null | tail -1)
[ -n "$FLOOD" ] || fail \
  "There is no record of a flood sent while five or more replicas were Ready." \
  "" \
  "Wait for the five replicas, then send nine requests at once to one of them:" \
  "  kubectl rollout status deploy/chat" \
  "  llmflood \$(kubectl get pods -l app=chat -o jsonpath='{.items[0].metadata.name}') 9"

FILE=/root/answers/step5
[ -s "$FILE" ] || fail \
  "There is no answer in $FILE yet." \
  "" \
  "Write what the HPA's number is and why it does not move:" \
  "  kubectl get hpa chat" \
  "  llmstats"

grep -qiE 'averag|mean' "$FILE" || fail \
  "$FILE does not say what the HPA's number is. It says:" \
  "  $(head -c 200 "$FILE")" \
  "" \
  "The HPA's figure is not the deepest queue. Compare it with the per-Pod values" \
  "it was computed from:" \
  "  kubectl get --raw \"/apis/custom.metrics.k8s.io/v1beta1/namespaces/serve/pods/*/vllm:num_requests_waiting\""

pass
