#!/bin/bash
LOG=/root/.check
STEP="Step 5 · A token that is not the ServiceAccount"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }
. /usr/local/lib/rbac-lab.sh

FILE=/root/answers/step5
[ -s "$FILE" ] || fail \
  "There is no answer in $FILE yet." \
  "" \
  "Write the username that 'auth whoami' reported when you passed --token:" \
  "  echo <username> > $FILE" \
  "" \
  "  kubectl --token=\"\$(kubectl -n rb create token dev)\" auth whoami"

[ "$(tr -d '[:space:]' < "$FILE")" == "kubernetes-admin" ] || fail \
  "'$(head -c 60 "$FILE")' is not what it reported." \
  "" \
  "Run it again and copy the Username line exactly. If it says the ServiceAccount," \
  "something is different about how you ran it:" \
  "  kubectl --token=\"\$(kubectl -n rb create token dev)\" auth whoami"

KC=/root/dev.kubeconfig
[ -s "$KC" ] || fail \
  "There is no kubeconfig at $KC yet." \
  "" \
  "Build one that has only dev's token, with 'kubectl config --kubeconfig=$KC':" \
  "  set-cluster, set-credentials --token=..., set-context, use-context"

grep -q 'client-certificate' "$KC" && fail \
  "$KC still carries a client certificate." \
  "" \
  "A request with a certificate is authenticated by the certificate, so the" \
  "token in the same file would never be looked at. Build the file from empty."

WHO=$(kubectl --kubeconfig="$KC" auth whoami -o jsonpath='{.status.userInfo.username}' 2>&1)
[ "$WHO" == "system:serviceaccount:rb:dev" ] || fail \
  "$KC authenticates as '$(echo "$WHO" | tail -1 | cut -c1-120)', not as dev." \
  "" \
  "  kubectl --kubeconfig=$KC auth whoami" \
  "" \
  "If it says Unauthorized, the token expired or was copied wrongly; mint a new one:" \
  "  kubectl -n rb create token dev --duration=4h"

kubectl --kubeconfig="$KC" logs web >/dev/null 2>&1 || fail \
  "dev's token cannot read the log." \
  "" \
  "It is dev, so the Role from step 1 should allow it:" \
  "  kubectl --kubeconfig=$KC logs web"

pf_ok --kubeconfig="$KC" || fail \
  "dev's token cannot port-forward. kubectl said:" \
  "  $(tail -1 /tmp/.pf.out | cut -c1-220)" \
  "" \
  "Step 3 gave dev that. Check it is still in place:" \
  "  kubectl -n rb get role,rolebinding"

kubectl --kubeconfig="$KC" exec web -- true >/dev/null 2>&1 && fail \
  "dev's token can exec into the Pod. dev has no exec rule." \
  "" \
  "Something in $KC is not dev: check what 'auth whoami' says."

kubectl --kubeconfig="$KC" get nodes >/dev/null 2>&1 && fail \
  "dev's token can list nodes. dev has no cluster-wide permissions." \
  "" \
  "Something in $KC is not dev: check what 'auth whoami' says."

pass
