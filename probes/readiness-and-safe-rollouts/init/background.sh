#!/bin/bash

ctr -n k8s.io images pull ghcr.io/stefanprodan/podinfo:6.5.4 >/dev/null 2>&1 \
  || crictl pull ghcr.io/stefanprodan/podinfo:6.5.4 >/dev/null 2>&1 \
  || true

mkdir -p /root/manifests

# v1 -- healthy, and deliberately shipped with NO readiness probe. That
# omission is the subject of step 1.
cat > /root/manifests/v1.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop
spec:
  replicas: 4
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
        image: ghcr.io/stefanprodan/podinfo:6.5.4
        ports:
        - containerPort: 9898
EOF

# v2-broken -- the container starts and stays up, but nothing ever listens on
# 9898. A crash would be easy to catch; this is the failure mode that isn't.
cat > /root/manifests/v2-broken.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop
spec:
  replicas: 4
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
        image: ghcr.io/stefanprodan/podinfo:6.5.4
        command: ["/bin/sh","-c","sleep 3600"]
        ports:
        - containerPort: 9898
EOF

# v1-probe -- identical to v1, plus the readiness probe added in step 2.
cat > /root/manifests/v1-probe.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop
spec:
  replicas: 4
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
        image: ghcr.io/stefanprodan/podinfo:6.5.4
        ports:
        - containerPort: 9898
        readinessProbe:
          httpGet:
            path: /readyz
            port: 9898
          periodSeconds: 3
          failureThreshold: 2
EOF

# v2-broken-probe -- the same non-serving release as v2-broken, but this time
# with a readiness probe that can actually catch it.
cat > /root/manifests/v2-broken-probe.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop
spec:
  replicas: 4
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
        image: ghcr.io/stefanprodan/podinfo:6.5.4
        command: ["/bin/sh","-c","sleep 3600"]
        ports:
        - containerPort: 9898
        readinessProbe:
          httpGet:
            path: /readyz
            port: 9898
          periodSeconds: 3
          failureThreshold: 2
EOF

# v2-flapping -- serves correctly for 25 seconds, then stops being ready.
# Long enough to pass a readiness probe on the way in; short enough to be
# useless. This is what defeats a readiness probe used on its own.
cat > /root/manifests/v2-flapping.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop
spec:
  replicas: 4
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
        image: ghcr.io/stefanprodan/podinfo:6.5.4
        command: ["/bin/sh","-c","./podinfo & APP=$!; sleep 25; wget -qO- --post-data='' localhost:9898/readyz/disable >/dev/null 2>&1; wait $APP"]
        ports:
        - containerPort: 9898
        readinessProbe:
          httpGet:
            path: /readyz
            port: 9898
          periodSeconds: 3
          failureThreshold: 2
EOF

cat > /root/manifests/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: shop
spec:
  type: NodePort
  selector:
    app: shop
  ports:
  - port: 80
    targetPort: 9898
    nodePort: 30080
EOF

# A one-liner the learner reuses all lab to measure real end-user impact.
cat > /usr/local/bin/hitshop <<'EOF'
#!/bin/bash
N=${1:-20}
ok=0; fail=0
for i in $(seq 1 "$N"); do
  if curl -s -m 2 -o /dev/null http://localhost:30080/; then ok=$((ok+1)); else fail=$((fail+1)); fi
done
echo "OK=$ok FAILED=$fail"
EOF
chmod +x /usr/local/bin/hitshop

kubectl apply -f /root/manifests/v1.yaml >/dev/null 2>&1
kubectl apply -f /root/manifests/service.yaml >/dev/null 2>&1
kubectl rollout status deployment/shop --timeout=180s >/dev/null 2>&1

touch /tmp/.initfinished
