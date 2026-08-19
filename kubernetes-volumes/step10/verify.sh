#!/bin/bash

kubectl get pod secret-pod -o yaml | grep -q "secret:" || exit 1

kubectl exec secret-pod -- cat /etc/secret/password | grep -q "s3cr3t"
