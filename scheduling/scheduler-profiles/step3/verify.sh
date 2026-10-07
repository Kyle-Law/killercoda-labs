#!/bin/bash
LOG=/root/.check
STEP="Step 3 · The profile you left out"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

configz_json() {
  curl -sk --cert /root/.configz.crt --key /root/.configz.key https://127.0.0.1:10259/configz 2>/dev/null
}
profile_chunk() {
  configz_json | sed 's/"schedulerName":"/\n"schedulerName":"/g' | grep "^\"schedulerName\":\"$1\""
}
profiles_list() {
  configz_json | grep -o '"schedulerName":"[^"]*"' | cut -d'"' -f4 | tr '\n' ' '
}
# A Pod created now has to be given a node with no help. $1 = name, $2 = scheduler
# (empty for none). Fake nodes, so there is nothing to pull.
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

CZ=$(configz_json)
[ -n "$CZ" ] || fail \
  "The scheduler is not answering on 127.0.0.1:10259." \
  "" \
  "  kubectl -n kube-system get pods -l component=kube-scheduler" \
  "  kubectl -n kube-system logs -l component=kube-scheduler --tail=20"

PCT=$(echo "$CZ" | grep -o '"percentageOfNodesToScore":[0-9]*' | cut -d: -f2)
[ "$PCT" == "50" ] || fail \
  "The scheduler is not running the team's configuration." \
  "" \
  "  percentageOfNodesToScore it is running: ${PCT:-<unset>}   (the team's file says 50)" \
  "" \
  "What it is running is what  configz  shows. The config file is only read when the" \
  "scheduler starts:  restart-scheduler"

STRAT=$(profile_chunk bin-packing | grep -o '"scoringStrategy":{"type":"[A-Za-z]*"' | head -1 | cut -d'"' -f6)
[ "$STRAT" == "MostAllocated" ] || fail \
  "The bin-packing profile is gone, or no longer scores MostAllocated (it says: ${STRAT:-<no such profile>})." \
  "" \
  "The task was to keep it. Profiles it is running: $(profiles_list)"

PACKED=$(probe check-packed bin-packing)
[ -n "$PACKED" ] || fail \
  "A Pod that asks for bin-packing was not given a node within 30 seconds." \
  "" \
  "  Profiles the scheduler is running: $(profiles_list)"

PLAIN=$(probe check-plain "")
[ -n "$PLAIN" ] || fail \
  "A Pod that names no scheduler was not given a node within 30 seconds, but one asking for bin-packing was." \
  "" \
  "  Profiles the scheduler is running: $(profiles_list)" \
  "" \
  "Nothing is wrong with the scheduler's health. Compare that list with what the Pod itself asks for:" \
  "  kubectl apply -f /root/plain.yaml" \
  "  kubectl get pod plain -o jsonpath='{.spec.schedulerName}'"

pass
