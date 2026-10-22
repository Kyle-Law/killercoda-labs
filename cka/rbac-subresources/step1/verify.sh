#!/bin/bash
#
# Killercoda only reads the exit code, so every exit path writes its reason to
# /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 1 · The yes that isn't"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }
. /usr/local/lib/rbac-lab.sh

FILE=/root/answers/step1
[ -s "$FILE" ] || fail \
  "There is no answer in $FILE yet." \
  "" \
  "Write the flag that makes 'kubectl auth can-i' ask about a subresource:" \
  "  echo <flag> > $FILE" \
  "" \
  "Start from what 'can-i get pods/log' actually asked -- 'verb resource/resourceName'" \
  "has no room for a subresource:" \
  "  kubectl auth can-i -h"

grep -qi 'subresource' "$FILE" || fail \
  "'$(head -c 60 "$FILE")' is not the flag." \
  "" \
  "It is a flag on 'kubectl auth can-i', and its name is the word for what" \
  "'log', 'exec' and 'portforward' are:" \
  "  kubectl auth can-i -h | grep -i sub"

OUT=$(as dev logs web 2>&1)
if [ $? -ne 0 ]; then
  fail \
    "dev still cannot read the log. The cluster says:" \
    "  $(echo "$OUT" | tail -1 | cut -c1-200)" \
    "" \
    "A Role names the thing it grants. Logs are not 'pods':" \
    "  kubectl create role log-reader --verb=get --resource=pods/log" \
    "  kubectl create rolebinding log-reader --role=log-reader --serviceaccount=rb:dev"
fi

as dev auth can-i get pods >/dev/null 2>&1 || fail \
  "dev can no longer read Pods." \
  "" \
  "The Role that gave it that is 'reader'. Add the log rule beside it rather" \
  "than replacing it:" \
  "  kubectl -n rb get role,rolebinding"

as dev exec web -- true >/dev/null 2>&1 && fail \
  "dev can now exec into the Pod, which was not asked for." \
  "" \
  "Only pods/log was wanted. Look for a rule that grants more than that:" \
  "  asdev auth can-i --list"

as dev auth can-i delete pods >/dev/null 2>&1 && fail \
  "dev can now delete Pods, which was not asked for." \
  "" \
  "Only 'get' on pods/log was wanted:" \
  "  asdev auth can-i --list"

pass
