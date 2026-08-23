#!/bin/bash

echo "Deploying api..."
while [ ! -f /tmp/step3-applied ]; do sleep 1; done

for i in $(seq 1 30); do
  READY=$(kubectl get deployment api -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" == "2" ] && break
  sleep 2
done

# record the starting revision so verify.sh can confirm it advances by
# exactly one, regardless of how many changes get batched in
REV=$(kubectl get rs -l app=api -o jsonpath='{.items[0].metadata.annotations.deployment\.kubernetes\.io/revision}' 2>/dev/null)
echo "$REV" > /root/api-starting-revision.txt

echo "Ready. Good luck!"
