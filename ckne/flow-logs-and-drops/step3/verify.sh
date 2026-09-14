#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 3 · Who is actually talking to this"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

# The deny must be gone, or "what is talking to this" has no traffic to see.
kubectl get netpol api-deny >/dev/null 2>&1 && fail \
  "'api-deny' is still in force, so nothing is reaching api to be observed." \
  "" \
  "Take it off first:" \
  "  kubectl delete netpol api-deny"

ANSWER=/root/answers/step3.txt
[ -f "$ANSWER" ] || fail \
  "No answer file at $ANSWER." \
  "" \
  "Count the callers, decide which one has no business being there, and write" \
  "its workload name:" \
  "  flows --since 60s --to-pod api | grep to-endpoint | awk '{print \$4}' \\" \
  "    | cut -d: -f1 | sort | uniq -c | sort -rn" \
  "  echo '<workload>' > $ANSWER"

grep -qi "scanner" "$ANSWER" || fail \
  "$ANSWER does not name the workload that should not be there." \
  "" \
  "It currently says:" \
  "  $(head -c 200 "$ANSWER")" \
  "" \
  "Every caller in that list is a real workload in this cluster. One of them" \
  "nobody authorised -- list them by name and it is the one you do not recognise" \
  "as part of the application:" \
  "  flows --since 60s --to-pod api | grep to-endpoint | awk '{print \$4}' \\" \
  "    | cut -d: -f1 | sort | uniq -c | sort -rn"

# Naming web instead of, or as well as, the scanner is the wrong finding --
# web is the legitimate caller.
grep -qiE "^web|web is (the )?unauthoris|web.*should not" "$ANSWER" && fail \
  "$ANSWER treats 'web' as the workload that should not be there." \
  "" \
  "web is the application's own front end -- it is supposed to call api, and" \
  "step 4 has to keep it working. Name only the caller that is not part of the" \
  "application."

pass
