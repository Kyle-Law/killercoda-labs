#!/bin/bash

helm repo add podinfo https://stefanprodan.github.io/podinfo >/dev/null 2>&1
helm repo update >/dev/null 2>&1

cat > /root/base-values.yaml <<'EOF'
replicaCount: 2
ui:
  message: "from base"
EOF

cat > /root/override-values.yaml <<'EOF'
replicaCount: 3
ui:
  message: "from override"
EOF

helm install podinfo-values2 podinfo/podinfo --version 6.5.4 --wait --timeout 90s

touch /tmp/step2-applied
