#!/bin/bash

echo "Deploying node-agent DaemonSet..."
while [ ! -f /tmp/step3-applied ]; do sleep 1; done

for i in $(seq 1 20); do
  READY=$(kubectl get daemonset node-agent -o jsonpath='{.status.numberReady}' 2>/dev/null)
  [ "$READY" == "1" ] && break
  sleep 2
done

# record the Pod's UID so verify.sh can prove it was genuinely orphaned and
# re-adopted, rather than deleted and recreated as a fresh object
kubectl get pod -l app=node-agent -o jsonpath='{.items[0].metadata.uid}' > /root/original-node-agent-uid.txt

echo "Ready. Good luck!"
