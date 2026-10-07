#!/bin/bash
LOG=/root/.check
STEP="Step 4 · A typo is a refusal"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

configz_json() {
  curl -sk --cert /root/.configz.crt --key /root/.configz.key https://127.0.0.1:10259/configz 2>/dev/null
}
profiles_list() {
  configz_json | grep -o '"schedulerName":"[^"]*"' | cut -d'"' -f4 | tr '\n' ' '
}
last_error() {
  { kubectl -n kube-system logs -l component=kube-scheduler --tail=30 2>/dev/null
    kubectl -n kube-system logs -l component=kube-scheduler --previous --tail=30 2>/dev/null; } \
    | grep -E '^E' | grep -v 'broadcaster already stopped' | tail -1 | cut -c1-260
}
probe() {
  kubectl delete pod "$1" --now --ignore-not-found >/dev/null 2>&1
  SN=""; [ -n "$2" ] && SN="schedulerName: $2"
  cat <<YAML | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: $1
spec:
  $SN
  nodeSelector:
    type: kwok
  tolerations:
  - key: kwok.x-k8s.io/node
    operator: Exists
  containers:
  - name: c
    image: busybox:1.36
    command: ["sleep", "60"]
YAML
  local n=""
  for _ in $(seq 1 10); do
    n=$(kubectl get pod "$1" -o jsonpath='{.spec.nodeName}' 2>/dev/null)
    [ -n "$n" ] && break
    sleep 3
  done
  kubectl delete pod "$1" --now --wait=false >/dev/null 2>&1
  echo "$n"
}

READY=""
for _ in $(seq 1 18); do
  READY=$(kubectl -n kube-system get pod -l component=kube-scheduler \
    -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)
  [ "$READY" == "true" ] && break
  sleep 5
done
[ "$READY" == "true" ] || fail \
  "kube-scheduler is not Ready." \
  "" \
  "  $(kubectl -n kube-system get pod -l component=kube-scheduler --no-headers 2>/dev/null | awk '{print $1, $2, $3, "restarts="$4}')" \
  "" \
  "What it last said:" \
  "  $(last_error)" \
  "" \
  "While it is down nothing is placing anything. Once the config is right, restart it:" \
  "  restart-scheduler"

CZ=$(configz_json)
[ -n "$CZ" ] || fail "kube-scheduler is Ready but not answering on 127.0.0.1:10259."

PCT=$(echo "$CZ" | grep -o '"percentageOfNodesToScore":[0-9]*' | cut -d: -f2)
[ "$PCT" == "100" ] || fail \
  "The scheduler is running, but its percentageOfNodesToScore is: ${PCT:-<unset>}" \
  "" \
  "  configz | grep -o '\"percentageOfNodesToScore\":[0-9]*'" \
  "" \
  "The config file is only read when the scheduler starts:  restart-scheduler"

for P in default-scheduler bin-packing; do
  echo "$CZ" | grep -q "\"schedulerName\":\"$P\"" || fail \
    "The running scheduler has no profile called $P." \
    "" \
    "  Profiles it is running: $(profiles_list)"
done

PLAIN=$(probe check-plain "")
[ -n "$PLAIN" ] || fail \
  "A Pod that names no scheduler was not given a node within 30 seconds." \
  "" \
  "  Profiles the scheduler is running: $(profiles_list)"

pass
