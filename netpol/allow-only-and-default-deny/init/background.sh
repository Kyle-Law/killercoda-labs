#!/bin/bash

ctr -n k8s.io images pull docker.io/stefanprodan/podinfo:6.6.0 >/dev/null 2>&1 \
  || crictl pull docker.io/stefanprodan/podinfo:6.6.0 >/dev/null 2>&1 \
  || true

kubectl create namespace shop >/dev/null 2>&1

for app in web api db; do
cat <<EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $app
  namespace: shop
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $app
  template:
    metadata:
      labels:
        app: $app
    spec:
      containers:
      - name: app
        image: stefanprodan/podinfo:6.6.0
        env:
        - name: PODINFO_UI_MESSAGE
          value: "$app"
        ports:
        - containerPort: 9898
---
apiVersion: v1
kind: Service
metadata:
  name: $app
  namespace: shop
spec:
  selector:
    app: $app
  ports:
  - port: 9898
    targetPort: 9898
EOF
done

# Probes one direction and prints ALLOWED / BLOCKED. A blocked connection is
# dropped rather than refused, so it hangs until the timeout -- hence -T 2
# rather than waiting on wget's default.
cat > /usr/local/bin/canreach <<'EOF'
#!/bin/bash
FROM=$1
TO=$2
if [ -z "$FROM" ] || [ -z "$TO" ]; then
  echo "usage: canreach <from> <to>   e.g. canreach web api"
  exit 1
fi
POD=$(kubectl -n shop get pods -l app="$FROM" --field-selector=status.phase=Running \
  -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.metadata.deletionTimestamp}{"\n"}{end}' 2>/dev/null \
  | awk -F'|' '$2 == "" { print $1; exit }')
if [ -z "$POD" ]; then
  echo "$FROM -> $TO : NO RUNNING POD"
  exit 0
fi
if kubectl -n shop exec "$POD" -- wget -q -T 2 -O /dev/null "http://$TO:9898/" 2>/dev/null; then
  echo "$FROM -> $TO : ALLOWED"
else
  echo "$FROM -> $TO : BLOCKED"
fi
EOF
chmod +x /usr/local/bin/canreach

# Discovers the apps rather than hardcoding them, so anything added to the
# namespace later shows up in the grid automatically.
cat > /usr/local/bin/matrix <<'EOF'
#!/bin/bash
APPS=$(kubectl -n shop get deploy -o jsonpath='{range .items[*]}{.metadata.name}{" "}{end}' 2>/dev/null)
[ -z "$APPS" ] && { echo "no deployments in shop"; exit 0; }
printf "%-14s" "from \\ to"
for t in $APPS; do printf "%-10s" "$t"; done
echo
for f in $APPS; do
  printf "%-14s" "$f"
  for t in $APPS; do
    if [ "$f" == "$t" ]; then
      printf "%-10s" "-"
    else
      printf "%-10s" "$(canreach "$f" "$t" | awk '{print $NF}')"
    fi
  done
  echo
done
EOF
chmod +x /usr/local/bin/matrix

kubectl -n shop rollout status deployment/web --timeout=180s >/dev/null 2>&1
kubectl -n shop rollout status deployment/api --timeout=180s >/dev/null 2>&1
kubectl -n shop rollout status deployment/db --timeout=180s >/dev/null 2>&1

touch /tmp/.initfinished
