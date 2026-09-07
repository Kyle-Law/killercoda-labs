#!/bin/bash

mkdir -p /root/app

cat > /root/app/resources.yaml <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-settings
data:
  MODE: "production"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: legacy-flags
data:
  USE_OLD_PARSER: "true"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: feature-toggles
data:
  NEW_UI: "false"
YAML

cat > /root/app/kustomization.yaml <<'YAML'
namespace: demo
resources:
  - resources.yaml
YAML

kubectl create namespace demo >/dev/null 2>&1

touch /tmp/.initfinished
