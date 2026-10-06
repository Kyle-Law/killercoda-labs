#!/bin/bash

mkdir -p /root/answers

# Killercoda shows only pass/fail, never a verify script's output, so each
# check writes its reason to /root/.check and `why` prints it.
cat > /usr/local/bin/why <<'WRAP'
#!/bin/bash
if [ -s /root/.check ]; then
  cat /root/.check
else
  echo "No check has run yet -- press CHECK, then run 'why' again."
fi
WRAP
chmod +x /usr/local/bin/why

# The cluster can still be coming up when this runs.
for _ in $(seq 1 60); do
  kubectl get nodes >/dev/null 2>&1 && break
  sleep 2
done
kubectl wait --for=condition=Ready node --all --timeout=180s >/dev/null 2>&1

# Which node the lab's experiments run against. Found by what it is not rather
# than by name, so it does not depend on the backend's naming.
WORKER=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$WORKER" ]; then
  touch /tmp/.initbroken
else
  echo "$WORKER" > /root/worker
fi

# Step 1: three Pods, all Pending, for three different reasons. batch-1 names a
# scheduler nobody runs, batch-2 is held by a scheduling gate, and batch-3 is
# read by the default scheduler and refused. Their names say nothing about which.
cat <<'YAML' | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: batch-1
spec:
  schedulerName: nightly-batch
  containers:
  - name: c
    image: busybox:1.36
    command: ["sleep", "3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: batch-2
spec:
  schedulingGates:
  - name: example.com/hold
  containers:
  - name: c
    image: busybox:1.36
    command: ["sleep", "3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: batch-3
spec:
  nodeSelector:
    disktype: ssd
  containers:
  - name: c
    image: busybox:1.36
    command: ["sleep", "3600"]
YAML

# Step 2 checks the learner bound the Pod they were given, not a copy of it.
for _ in $(seq 1 30); do
  UID_=$(kubectl get pod batch-1 -o jsonpath='{.metadata.uid}' 2>/dev/null)
  [ -n "$UID_" ] && break
  sleep 1
done
echo "$UID_" > /root/.batch-1.uid

# Plumbing the learner applies rather than writes. Every Pod below names a
# scheduler on purpose: step 2's ghost names one nobody runs, so the default
# scheduler cannot bind it first, and steps 3 and 5 name the one the learner
# writes.
cat > /root/ghost.yaml <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: ghost
spec:
  schedulerName: nightly-batch
  containers:
  - name: c
    image: busybox:1.36
    command: ["sleep", "3600"]
YAML

cat > /root/web.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      schedulerName: by-hand
      containers:
      - name: web
        image: busybox:1.36
        command: ["sleep", "3600"]
YAML

cat > /root/big.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: big
spec:
  replicas: 2
  selector:
    matchLabels:
      app: big
  template:
    metadata:
      labels:
        app: big
    spec:
      schedulerName: by-hand
      containers:
      - name: big
        image: busybox:1.36
        command: ["sleep", "3600"]
        resources:
          requests:
            cpu: "1000"
YAML

touch /tmp/.initfinished
