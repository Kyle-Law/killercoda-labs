#!/bin/bash

ctr -n k8s.io images pull docker.io/stefanprodan/podinfo:6.5.4 >/dev/null 2>&1 \
  || crictl pull docker.io/stefanprodan/podinfo:6.5.4 >/dev/null 2>&1 \
  || true
# Pulled ahead of step 2, where bumping the base image is the whole point.
ctr -n k8s.io images pull docker.io/stefanprodan/podinfo:6.6.0 >/dev/null 2>&1 \
  || crictl pull docker.io/stefanprodan/podinfo:6.6.0 >/dev/null 2>&1 \
  || true

mkdir -p /root/app/base /root/app/overlays/dev

cat > /root/app/base/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop
spec:
  replicas: 1
  selector:
    matchLabels:
      app: shop
  template:
    metadata:
      labels:
        app: shop
    spec:
      containers:
      - name: app
        image: stefanprodan/podinfo:6.5.4
        ports:
        - containerPort: 9898
EOF

cat > /root/app/base/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: shop
spec:
  selector:
    app: shop
  ports:
  - port: 80
    targetPort: 9898
EOF

cat > /root/app/base/kustomization.yaml <<'EOF'
resources:
  - deployment.yaml
  - service.yaml
EOF

cat > /root/app/overlays/dev/kustomization.yaml <<'EOF'
resources:
  - ../../base

namePrefix: dev-
EOF

# Picks one Running Pod belonging to the named Deployment. Deliberately not
# `kubectl exec deploy/...`, which can select a Pod that is still terminating
# just after a rollout and report a value that is about to disappear.
# A Pod that is shutting down still reports phase=Running until it is gone, so
# a deletionTimestamp check is needed too -- otherwise this returns a Pod from
# the previous generation for a few seconds after every rollout.
cat > /usr/local/bin/shoppod <<'EOF'
#!/bin/bash
DEPLOY=${1:-dev-shop}
kubectl get pods --field-selector=status.phase=Running \
  -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.metadata.deletionTimestamp}{"\n"}{end}' 2>/dev/null \
  | grep "^${DEPLOY}-" \
  | awk -F'|' '$2 == "" { print "pod/" $1; exit }'
EOF
chmod +x /usr/local/bin/shoppod

# Reads the message the running app is actually serving -- which is not always
# the same as what its ConfigMap currently says. That gap is step 4.
cat > /usr/local/bin/shopmsg <<'EOF'
#!/bin/bash
DEPLOY=${1:-dev-shop}
POD=$(shoppod "$DEPLOY")
[ -z "$POD" ] && { echo '(no running pod)'; exit 0; }
kubectl exec "$POD" -- wget -qO- localhost:9898/ 2>/dev/null \
  | grep -o '"message": "[^"]*"' || echo '(no message set)'
EOF
chmod +x /usr/local/bin/shopmsg

# Same idea for the running image version, used in step 2.
cat > /usr/local/bin/shopver <<'EOF'
#!/bin/bash
DEPLOY=${1:-dev-shop}
POD=$(shoppod "$DEPLOY")
[ -z "$POD" ] && { echo '(no running pod)'; exit 0; }
kubectl exec "$POD" -- wget -qO- localhost:9898/ 2>/dev/null \
  | grep -o '"version": "[^"]*"' || echo '(unknown)'
EOF
chmod +x /usr/local/bin/shopver

touch /tmp/.initfinished
