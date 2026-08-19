#!/bin/bash

kubectl get pod shared-data -o yaml | grep -q "emptyDir:" || exit 1

kubectl exec shared-data -c reader -- cat /data/message.txt | grep -q hello-from-writer
