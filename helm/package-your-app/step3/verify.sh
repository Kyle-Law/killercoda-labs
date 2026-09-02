#!/bin/bash

# the HTML file itself must carry the value reference - otherwise the page
# could have been inlined into the template with files/index.html left stale
grep -q "Values.environment" /root/charts/site/files/index.html 2>/dev/null || exit 1

# and the environment must genuinely come from the value: re-render with a
# third value the task never mentions, so a hardcoded "dev" cannot follow it
RENDER=$(helm template probe /root/charts/site --set environment=staging 2>/dev/null)
echo "$RENDER" | grep -q "Hello from staging" || exit 1

# and the live release must be serving the dev text
for i in $(seq 1 18); do
  curl -s --max-time 5 http://localhost:30080 2>/dev/null | grep -q "Hello from dev" && exit 0
  sleep 5
done

exit 1
