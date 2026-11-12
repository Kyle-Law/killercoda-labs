#!/bin/bash
#
# Killercoda only reads the exit code, so every exit path writes its reason to
# /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 2 · The name from the runbook"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }
hpa() { kubectl -n serve get hpa chat -o jsonpath="$1" 2>/dev/null; }

kubectl -n serve get hpa chat >/dev/null 2>&1 || fail \
  "There is no HPA called 'chat' in namespace serve." \
  "" \
  "Apply the runbook's version and fix it from there:" \
  "  kubectl apply -f /root/hpa-queue.yaml"

TYPE=$(hpa '{.spec.metrics[0].type}')
[ "$TYPE" == "Pods" ] || fail \
  "The HPA's metric is of type '$TYPE', not Pods." \
  "" \
  "This step keeps the runbook's design -- a Pods metric on the queue depth --" \
  "and fixes only what is wrong with it:" \
  "  kubectl apply -f /root/hpa-queue.yaml"

NAME=$(hpa '{.spec.metrics[0].pods.metric.name}')
case "$NAME" in
  *num_requests_waiting*) ;;
  *) fail \
    "The HPA scales on '$NAME', which is not the queue depth." \
    "" \
    "The queue is the waiting count, not the running one: running is capped at" \
    "the server's --max-num-seqs and stays there however deep the queue gets." ;;
esac

ACTIVE=$(hpa '{.status.conditions[?(@.type=="ScalingActive")].status}')
if [ "$ACTIVE" != "True" ]; then
  MSG=$(hpa '{.status.conditions[?(@.type=="ScalingActive")].message}')
  fail \
    "The HPA cannot compute a replica count yet (ScalingActive=${ACTIVE:-unknown})." \
    "" \
    "  $(echo "$MSG" | cut -c1-230)" \
    "" \
    "It asks the custom metrics API, not Prometheus. Ask the API what it has:" \
    "  kubectl get --raw /apis/custom.metrics.k8s.io/v1beta1 | grep -o '\"name\":\"pods/vllm[^\"]*\"'" \
    "" \
    "If you have just fixed it, give the HPA 15 to 30 seconds and check again."
fi

pass
