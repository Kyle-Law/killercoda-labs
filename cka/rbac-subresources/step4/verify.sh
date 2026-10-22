#!/bin/bash
LOG=/root/.check
STEP="Step 4 · The wildcard that grants nothing"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }
. /usr/local/lib/rbac-lab.sh

FILE=/root/answers/step4
[ -s "$FILE" ] || fail \
  "There is no answer in $FILE yet." \
  "" \
  "Write how many of the four things the original Role allowed -- see Pods," \
  "read logs, exec, port-forward:" \
  "  echo <number> > $FILE" \
  "" \
  "Try each as ops with the Role as it was given to you."

[ "$(tr -d '[:space:]' < "$FILE")" == "0" ] || fail \
  "'$(head -c 60 "$FILE")' is not right." \
  "" \
  "Run all four as ops against the Role as it was first written, and count the" \
  "ones that worked. The rule shows up in 'can-i --list', which is what makes" \
  "this easy to get wrong:" \
  "  kubectl -n rb get role ops-pods -o jsonpath='{.rules}'"

kubectl -n rb get role ops-pods -o jsonpath='{.rules[*].resources}' | grep -q 'pods/\*' && fail \
  "The Role still contains 'pods/*'." \
  "" \
  "RBAC matches '*' and '*/<subresource>', never '<resource>/*'. Name the" \
  "subresources:" \
  "  kubectl -n rb get role ops-pods -o yaml"

retry as ops get pods >/dev/null 2>&1 || fail \
  "ops cannot see Pods." \
  "  $(as ops get pods 2>&1 | tail -1 | cut -c1-200)" \
  "" \
  "Seeing every Pod is 'list' on 'pods', and 'get' is for one by name -- ask for both."

OUT=$(as ops logs web 2>&1) || fail \
  "ops cannot read logs. The cluster says:" \
  "  $(echo "$OUT" | tail -1 | cut -c1-200)" \
  "" \
  "That is 'get' on 'pods/log'."

OUT=$(as ops exec web -- true 2>&1) || fail \
  "ops cannot exec. The cluster says:" \
  "  $(echo "$OUT" | tail -1 | cut -c1-200)" \
  "" \
  "That is 'create' on 'pods/exec', and 'get' on 'pods' for the lookup."

pf_ok -n rb --as=system:serviceaccount:rb:ops || fail \
  "ops cannot port-forward. kubectl said:" \
  "  $(tail -1 /tmp/.pf.out | cut -c1-220)" \
  "" \
  "That is 'create' on 'pods/portforward'."

as ops auth can-i create pods >/dev/null 2>&1 && fail \
  "ops can create Pods, which was ruled out." \
  "" \
  "A rule has one list of verbs. 'create' belongs only on the two streaming" \
  "subresources, so they need a rule of their own, apart from 'get':" \
  "  asops auth can-i --list"

as ops auth can-i delete pods >/dev/null 2>&1 && fail \
  "ops can delete Pods, which was ruled out." \
  "" \
  "  asops auth can-i --list"

pass
