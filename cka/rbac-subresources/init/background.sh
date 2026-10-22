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

# Three short names for "run kubectl as that ServiceAccount". They are only
# --as=system:serviceaccount:rb:<name> and -n rb in front of the arguments.
for SA in dev runner ops; do
  cat > /usr/local/bin/as$SA <<WRAP
#!/bin/bash
exec kubectl -n rb --as=system:serviceaccount:rb:$SA "\$@"
WRAP
  chmod +x /usr/local/bin/as$SA
done

# Shared by the checks. as() runs kubectl as a ServiceAccount; pf_ok() starts a
# port-forward with the given kubectl arguments, fetches a page through it and
# reports whether the page came back.
mkdir -p /usr/local/lib
cat > /usr/local/lib/rbac-lab.sh <<'LIB'
as() { local sa=$1; shift; kubectl -n rb --as=system:serviceaccount:rb:$sa "$@"; }
retry() { local i; for i in 1 2 3 4 5 6; do "$@" && return 0; sleep 1; done; return 1; }
pf_ok() {
  local port=$((20000 + RANDOM % 5000)) pid body i
  kubectl "$@" port-forward pod/web "$port":80 >/tmp/.pf.out 2>&1 &
  pid=$!
  for i in 1 2 3 4 5 6; do
    sleep 1
    body=$(curl -s -m 2 "localhost:$port" 2>/dev/null)
    [ "$body" == "ok" ] && break
  done
  kill $pid 2>/dev/null; wait $pid 2>/dev/null
  [ "$body" == "ok" ]
}
LIB

# The cluster can still be coming up when this runs.
for _ in $(seq 1 60); do
  kubectl get nodes >/dev/null 2>&1 && break
  sleep 2
done
kubectl wait --for=condition=Ready node --all --timeout=180s >/dev/null 2>&1

kubectl create namespace rb >/dev/null 2>&1
kubectl config set-context --current --namespace=rb >/dev/null 2>&1
kubectl -n rb create serviceaccount dev >/dev/null 2>&1
kubectl -n rb create serviceaccount runner >/dev/null 2>&1
kubectl -n rb create serviceaccount ops >/dev/null 2>&1

# Something that answers on a port, so port-forward has something to reach.
cat <<'YAML' | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: rb
spec:
  containers:
  - name: web
    image: busybox:1.36
    command: ["sh", "-c", "mkdir -p /www && echo ok > /www/index.html && echo started && exec httpd -f -v -p 80 -h /www"]
YAML

# dev can read Pods and nothing else. ops has a Role a colleague wrote.
cat <<'YAML' | kubectl apply -f - >/dev/null 2>&1
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: reader
  namespace: rb
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: reader
  namespace: rb
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: reader}
subjects:
- {kind: ServiceAccount, name: dev, namespace: rb}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ops-pods
  namespace: rb
rules:
- apiGroups: [""]
  resources: ["pods/*"]
  verbs: ["get", "create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ops-pods
  namespace: rb
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: ops-pods}
subjects:
- {kind: ServiceAccount, name: ops, namespace: rb}
YAML

if ! kubectl -n rb wait --for=condition=Ready pod/web --timeout=180s >/dev/null 2>&1; then
  touch /tmp/.initbroken
fi
touch /tmp/.initfinished
