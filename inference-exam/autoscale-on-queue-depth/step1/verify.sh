#!/bin/bash
#
# Killercoda only reads the exit code, so every exit path writes its reason to
# /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 1 · A full queue and an idle CPU"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

[ -e /tmp/llmload.out ] || fail \
  "No load has been run yet, so there is nothing to read." \
  "" \
  "  llmload 2 30" \
  "" \
  "then, a few times over the next minute:" \
  "  kubectl get hpa chat" \
  "  llmstats"

FILE=/root/answers/step1
[ -s "$FILE" ] || fail \
  "There is no answer in $FILE yet." \
  "" \
  "Write both readings, taken at the same moment: the HPA's CPU figure and the" \
  "number of requests waiting:" \
  "  cat > $FILE <<'EOF'" \
  "  ... your two readings ..." \
  "  EOF"

grep -qi 'cpu' "$FILE" || fail \
  "$FILE does not mention the CPU reading. It says:" \
  "  $(head -c 200 "$FILE")" \
  "" \
  "The point is the two numbers side by side. What did the HPA's TARGETS column say?" \
  "  kubectl get hpa chat"

grep -qiE 'wait|queue' "$FILE" || fail \
  "$FILE does not mention the requests waiting. It says:" \
  "  $(head -c 200 "$FILE")" \
  "" \
  "The model server counts them itself; it is the WAITING column:" \
  "  llmstats"

pass
