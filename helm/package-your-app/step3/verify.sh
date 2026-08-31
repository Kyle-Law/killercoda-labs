#!/bin/bash

# the environment must come from the value, not be hardcoded in the HTML -
# rendering the chart with a different value has to change the output
RENDER=$(helm template probe /root/charts/site --set environment=staging 2>/dev/null)
echo "$RENDER" | grep -q "Hello from staging" || exit 1

# and the live release must be serving the dev text
for i in $(seq 1 18); do
  curl -s --max-time 5 http://localhost:30080 2>/dev/null | grep -q "Hello from dev" && exit 0
  sleep 5
done

exit 1
