#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 2 · All of it goes to one replica, and that is correct"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

ANSWER=/root/answers/step2.txt
[ -f "$ANSWER" ] || fail \
  "No answer file at $ANSWER." \
  "" \
  "Run both loads and write down two things: which replica took the long-prompt" \
  "traffic, and why the short prompt did not concentrate the same way." \
  "  igload 60 long 1" \
  "  igload 60 same" \
  "  echo '<pod-name> took all of it; short prompts ...' > $ANSWER"

PODS=$(kubectl get pod -l app=vllm-qwen3-32b -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
[ -n "$PODS" ] || fail \
  "No simulator Pods are running, so there was nothing to measure." \
  "" \
  "  kubectl get pods -l app=vllm-qwen3-32b"

NAMED=0
for p in $PODS; do grep -q "$p" "$ANSWER" && NAMED=1; done
[ "$NAMED" == "1" ] || fail \
  "$ANSWER does not name any of the replicas that are running." \
  "" \
  "It currently says:" \
  "  $(head -c 220 "$ANSWER")" \
  "" \
  "igload prints the requests each replica served during that run only. Name the" \
  "one that took the long-prompt traffic, by its full Pod name:" \
  "  igload 60 long 1"

# The second half of the finding: why the short prompt behaved differently.
grep -qiE "prefix|chunk|short|cache" "$ANSWER" || fail \
  "$ANSWER names the replica but does not say why the short prompt spread out." \
  "" \
  "It currently says:" \
  "  $(head -c 220 "$ANSWER")" \
  "" \
  "Both runs went through the same picker with the same settings, so the" \
  "difference is in the prompts, not the configuration. The picker scores" \
  "replicas partly on how much of the prompt one of them has already seen --" \
  "and that comparison is done in fixed-size blocks, so a prompt can be too" \
  "small to be worth anything. Say so in the file."

pass
