#!/bin/bash

echo "Deploying backup-job CronJob..."
while [ ! -f /tmp/step4-applied ]; do sleep 1; done

for i in $(seq 1 20); do
  kubectl get cronjob backup-job >/dev/null 2>&1 && break
  sleep 2
done

echo "Ready. Good luck!"
