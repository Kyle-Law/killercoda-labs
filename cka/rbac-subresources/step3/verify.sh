#!/bin/bash
LOG=/root/.check
STEP="Step 3 · An error that does not look like RBAC"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }
. /usr/local/lib/rbac-lab.sh

FILE=/root/answers/step3
[ -s "$FILE" ] || fail \
  "There is no answer in $FILE yet." \
  "" \
  "Write the resource the error ends on:" \
  "  echo <resource> > $FILE" \
  "" \
  "It is the last thing in the sentence that starts 'cannot create resource':" \
  "  asdev port-forward web 8080:80"

grep -qi 'portforward' "$FILE" || fail \
  "'$(head -c 60 "$FILE")' is not what the error ends on." \
  "" \
  "Run the port-forward as dev and read to the end of the line. The resource is" \
  "named in quotes, after 'cannot create resource'."

as dev auth can-i get pods >/dev/null 2>&1 || fail \
  "dev can no longer read Pods." \
  "" \
  "port-forward needs 'get' on the Pod as well as the portforward rule, and the" \
  "Role 'reader' gave it that:" \
  "  kubectl -n rb get role,rolebinding"

if ! retry pf_ok -n rb --as=system:serviceaccount:rb:dev; then
  fail \
    "A port-forward as dev did not get the page back. kubectl said:" \
    "  $(tail -1 /tmp/.pf.out | cut -c1-220)" \
    "" \
    "port-forward is a 'create' on pods/portforward:" \
    "  kubectl create role portforward --verb=create --resource=pods/portforward" \
    "  kubectl create rolebinding portforward --role=portforward --serviceaccount=rb:dev"
fi

as dev exec web -- true >/dev/null 2>&1 && fail \
  "dev can now exec into the Pod, which was not asked for." \
  "" \
  "Only pods/portforward was wanted:" \
  "  asdev auth can-i --list"

as dev auth can-i delete pods >/dev/null 2>&1 && fail \
  "dev can now delete Pods, which was not asked for." \
  "" \
  "  asdev auth can-i --list"

pass
