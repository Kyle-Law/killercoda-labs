#!/bin/bash
LOG=/root/.check
STEP="Step 2 · Exec needs two rules"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }
. /usr/local/lib/rbac-lab.sh

FILE=/root/answers/step2
[ -s "$FILE" ] || fail \
  "There is no answer in $FILE yet." \
  "" \
  "Write the rule that the second error asked for, as 'verb resource':" \
  "  echo '<verb> <resource>' > $FILE" \
  "" \
  "Bind a Role with only 'create' on 'pods/exec', run the exec again, and read" \
  "the whole error."

ANS=$(tr 'A-Z' 'a-z' < "$FILE")
echo "$ANS" | grep -qw 'get' && echo "$ANS" | grep -qw 'pods' || fail \
  "'$(head -c 60 "$FILE")' is not the rule the second error named." \
  "" \
  "Run the exec as runner with only 'create pods/exec' in place. The refusal" \
  "that comes back names a verb and a resource -- write those two words:" \
  "  asrunner exec web -- ls"

echo "$ANS" | grep -q 'pods/' && fail \
  "'$(head -c 60 "$FILE")' names a subresource. The second error did not." \
  "" \
  "It named a plain resource -- the Pod itself, not something under it."

OUT=$(as runner exec web -- ls 2>&1)
if [ $? -ne 0 ]; then
  if echo "$OUT" | grep -q 'resource "pods" in API group'; then
    fail \
      "runner can open an exec session but cannot find the Pod to open it in." \
      "  $(echo "$OUT" | tail -1 | cut -c1-200)" \
      "" \
      "exec needs two rules. This is the second one -- the lookup, not the session."
  fi
  fail \
    "runner still cannot exec. The cluster says:" \
    "  $(echo "$OUT" | tail -1 | cut -c1-200)" \
    "" \
    "exec is a 'create' on a subresource of pods:" \
    "  kubectl create role exec-only --verb=create --resource=pods/exec" \
    "  kubectl create rolebinding exec-only --role=exec-only --serviceaccount=rb:runner"
fi

as runner logs web >/dev/null 2>&1 && fail \
  "runner can read logs, which was not asked for." \
  "" \
  "Only exec was wanted:" \
  "  asrunner auth can-i --list"

as runner auth can-i list pods >/dev/null 2>&1 && fail \
  "runner can list Pods, which was not asked for." \
  "" \
  "exec needs 'get' on a named Pod, not 'list' on all of them:" \
  "  asrunner auth can-i --list"

as runner auth can-i delete pods >/dev/null 2>&1 && fail \
  "runner can delete Pods, which was not asked for." \
  "" \
  "  asrunner auth can-i --list"

pass
