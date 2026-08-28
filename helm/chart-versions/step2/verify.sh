#!/bin/bash

# Resolve the expected version from the repo rather than hardcoding it, so this
# still grades correctly if podinfo publishes further 6.5.x patches.
# Row 1 is the header, row 2 the newest, row 3 the second newest; column 2 is
# CHART VERSION. Kept to awk/grep so it needs no jq, yq or python on the box.
SECOND=$(helm search repo podinfo/podinfo --version '~6.5' -l 2>/dev/null | awk 'NR==3{print $2}')
[ -n "$SECOND" ] || exit 1

for i in $(seq 1 12); do
  # 'helm ls' prints the chart as <name>-<version>, e.g. podinfo-6.5.3
  if helm ls 2>/dev/null | grep -E "^podinfo[[:space:]]" | grep -q "podinfo-${SECOND}"; then
    exit 0
  fi
  sleep 5
done

exit 1
