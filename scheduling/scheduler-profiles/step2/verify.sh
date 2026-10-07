#!/bin/bash
LOG=/root/.check
STEP="Step 2 · A profile that does not pack"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

# The scheduler's running configuration. Not the file: what the process loaded.
configz_json() {
  curl -sk --cert /root/.configz.crt --key /root/.configz.key https://127.0.0.1:10259/configz 2>/dev/null
}
# The chunk of that JSON belonging to one profile.
profile_chunk() {
  configz_json | sed 's/"schedulerName":"/\n"schedulerName":"/g' | grep "^\"schedulerName\":\"$1\""
}
# Pods being deleted still carry a nodeName for a few seconds, and they are
# not where the Deployment is going.
nodes_of() {
  kubectl get pods -l "app=$1" -o go-template='{{range .items}}{{if not .metadata.deletionTimestamp}}{{.spec.nodeName}}{{"\n"}}{{end}}{{end}}' 2>/dev/null | grep . | sort -u | wc -l
}
running_of() {
  kubectl get pods -l "app=$1" --no-headers 2>/dev/null | awk '$3=="Running"' | wc -l
}

CZ=$(configz_json)
[ -n "$CZ" ] || fail \
  "The scheduler is not answering on 127.0.0.1:10259." \
  "" \
  "  kubectl -n kube-system get pods -l component=kube-scheduler" \
  "  kubectl -n kube-system logs -l component=kube-scheduler --tail=20"

echo "$CZ" | grep -q '"schedulerName":"bin-packing"' || fail \
  "The running scheduler has no profile called bin-packing." \
  "" \
  "  Profiles it is running: $(echo "$CZ" | grep -o '"schedulerName":"[^"]*"' | cut -d'"' -f4 | tr '\n' ' ')" \
  "" \
  "Editing the config file does nothing until the scheduler restarts:  restart-scheduler" \
  "and  configz  shows what it actually loaded."

STRAT=$(profile_chunk bin-packing | grep -o '"scoringStrategy":{"type":"[A-Za-z]*"' | head -1 | cut -d'"' -f6)
[ "$STRAT" == "MostAllocated" ] || fail \
  "The bin-packing profile exists, but its NodeResourcesFit strategy is: ${STRAT:-<unset>}" \
  "" \
  "It should be scoring nodes by how full they already are." \
  "  configz | grep -o '\"scoringStrategy\":{\"type\":\"[A-Za-z]*\"'"

for D in spread packed; do
  kubectl get deployment "$D" >/dev/null 2>&1 || fail \
    "There is no Deployment called '$D'." \
    "" \
    "Apply the two you were given:  kubectl apply -f /root/spread.yaml -f /root/packed.yaml"
done

for _ in $(seq 1 12); do
  [ "$(running_of spread)" -ge 12 ] && [ "$(running_of packed)" -ge 12 ] && break
  sleep 5
done
[ "$(running_of spread)" -ge 12 ] || fail \
  "Only $(running_of spread) of the 12 'spread' Pods are Running." \
  "" \
  "  kubectl get pods -l app=spread -o wide"
[ "$(running_of packed)" -ge 12 ] || fail \
  "Only $(running_of packed) of the 12 'packed' Pods are Running." \
  "" \
  "  kubectl get pods -l app=packed -o wide" \
  "" \
  "A Pending 'packed' Pod has no node: nothing running now has a profile called bin-packing."

SPREAD=$(nodes_of spread)
PACKED=$(nodes_of packed)

[ "$SPREAD" -ge 8 ] || fail \
  "The default profile no longer spreads: 'spread' is using $SPREAD nodes." \
  "" \
  "The task was to change what bin-packing does, not what everything else does." \
  "'spread' asks for default-scheduler, whose behaviour should be exactly what it was."

[ "$PACKED" -le 2 ] || fail \
  "'packed' is using $PACKED nodes. It should be using one or two." \
  "" \
  "  kubectl get pods -l app=packed -o wide" \
  "" \
  "Two different things could be wrong, and they look the same from here:" \
  "  - the scheduler is not doing what you think (compare it with:  configz)" \
  "  - it is, but these Pods were placed before it was. Placed Pods never move:" \
  "      kubectl delete -f /root/packed.yaml && kubectl apply -f /root/packed.yaml" \
  "" \
  "If it still spreads after that, something other than NodeResourcesFit is deciding." \
  "The scheduler will say what: it logs every plugin's score for every node with" \
  "--vmodule=schedule_one=10  on its command line."

pass
