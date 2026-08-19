#!/bin/bash

kubectl get --raw /healthz --request-timeout=5s 2>/dev/null | grep -q "^ok$"
