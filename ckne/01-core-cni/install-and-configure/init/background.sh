#!/bin/bash

CILIUM_VERSION=1.19.7

if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  # Invoked through bash rather than executed directly: /tmp is mounted noexec
  # on some node images, and the exec bit would not help there.
  bash /tmp/get_helm.sh >/dev/null 2>&1
fi

helm repo add cilium https://helm.cilium.io/ >/dev/null 2>&1
helm repo update >/dev/null 2>&1

# Pull ahead of time so step 2 is an install rather than a download. Without a
# CNI there is no pod network, but image pulls go through containerd on the
# host and are unaffected.
for IMG in \
  quay.io/cilium/cilium:v${CILIUM_VERSION} \
  quay.io/cilium/operator-generic:v${CILIUM_VERSION} \
  quay.io/cilium/hubble-relay:v${CILIUM_VERSION} \
  registry.k8s.io/e2e-test-images/agnhost:2.53 ; do
  ctr -n k8s.io images pull "$IMG" >/dev/null 2>&1 \
    || crictl pull "$IMG" >/dev/null 2>&1 \
    || true
done

# A small HTTP app, started while the network still works so its image is
# local. It gets torn down again below and spends the whole of step 1 unable
# to start -- which is the point.
cat <<'EOF' | kubectl apply -f - >/dev/null 2>&1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: registry.k8s.io/e2e-test-images/agnhost:2.53
        args: ["netexec", "--http-port=8080"]
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 8080
EOF
kubectl rollout status deployment/web --timeout=180s >/dev/null 2>&1

# ---------------------------------------------------------------------------
# Remove whatever CNI this backend shipped with, so the lab starts from a
# genuinely CNI-less cluster.
#
# Written to work whichever CNI that turns out to be. A CNI is identified by
# the one thing only a CNI does: hostPath-mounting the directory the kubelet
# reads its network configuration from. Nothing else has a reason to.
# ---------------------------------------------------------------------------
CNI_DS=$(kubectl get ds -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{range .spec.template.spec.volumes[*]}{" "}{.hostPath.path}{end}{"\n"}{end}' 2>/dev/null \
  | awk '/\/etc\/cni/ {print $1}')

for REF in $CNI_DS; do
  NS=${REF%%/*}
  NAME=${REF##*/}

  # Helm-installed CNIs leave a release behind. Deleting only the DaemonSet
  # would let step 2's `helm install` collide with it, so uninstall properly
  # when Helm's own annotations say a release owns this object.
  REL=$(kubectl -n "$NS" get ds "$NAME" -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}' 2>/dev/null)
  RELNS=$(kubectl -n "$NS" get ds "$NAME" -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' 2>/dev/null)

  if [ -n "$REL" ]; then
    helm uninstall "$REL" -n "${RELNS:-$NS}" --wait --timeout 120s >/dev/null 2>&1
  fi

  kubectl -n "$NS" delete ds "$NAME" --ignore-not-found --wait=true >/dev/null 2>&1

  # An operator or controller left running would just put the DaemonSet back.
  # They are conventionally named for the same CNI, so match on that prefix.
  PREFIX=${NAME%%-*}
  kubectl -n "$NS" get deploy -o name 2>/dev/null \
    | grep "deployment.apps/${PREFIX}" \
    | xargs -r kubectl -n "$NS" delete --ignore-not-found --wait=true >/dev/null 2>&1
done

rm -f /etc/cni/net.d/* 2>/dev/null

# host-local IPAM keeps its allocations in a directory on the node, not in the
# API server. Left behind, it would go on reserving addresses for Pods that no
# longer exist.
rm -rf /var/lib/cni/networks/* /run/cni-ipam-state/* 2>/dev/null

# containerd keeps the network configuration it parsed in memory. Deleting the
# file alone leaves it happily wiring up new Pods from a cache, while the node
# simultaneously reports NetworkNotReady -- a genuinely confusing half-state.
# Restart it so the runtime's view matches what is actually on disk.
systemctl restart containerd 2>/dev/null || true
sleep 5

# The kubelet re-reports node status on its own schedule, and the container
# runtime only rereads the config directory periodically. Wait for the node to
# actually go NotReady -- until it has, Pods created in the gap would still be
# wired up by the plugin that is on its way out.
for _ in $(seq 1 60); do
  STATUS=$(kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  [ "$STATUS" == "False" ] && break
  sleep 3
done

# Only now are surviving Pods safe to recreate. They keep the addresses they
# were already given, so without this the cluster would look deceptively
# healthy -- and worse, those addresses came from an IPAM that no longer
# exists, so the next plugin to allocate would hand out the same ones again.
# Every Pod holding an address from the departed CNI has to go. hostNetwork
# Pods never had one: they use the node's address, which is why the control
# plane survives all of this.
# A jsonpath filter cannot express this: hostNetwork is absent rather than
# false on an ordinary Pod, so `@.spec.hostNetwork!=true` matches nothing at
# all. go-template treats the missing field as falsy, which is what is wanted.
PODSEL='{{range .items}}{{if not .spec.hostNetwork}}{{.metadata.namespace}}{{" "}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}'

kubectl get pods -A -o go-template="$PODSEL" 2>/dev/null \
  | while read -r NS POD; do
      # --force is needed, not cosmetic: a graceful delete asks the runtime to
      # tear the Pod's network down, and there is no longer a plugin to do it,
      # so the Pod would sit in Terminating indefinitely.
      [ -n "$POD" ] && kubectl -n "$NS" delete pod "$POD" --ignore-not-found \
        --force --grace-period=0 --wait=false >/dev/null 2>&1
    done

# Confirm the Pods really are stuck rather than quietly recovering, so the
# scenario never opens on a cluster that looks fine.
PHASESEL='{{range .items}}{{if not .spec.hostNetwork}}{{.status.phase}}{{"\n"}}{{end}}{{end}}'
for _ in $(seq 1 20); do
  RUNNING=$(kubectl get pods -A -o go-template="$PHASESEL" 2>/dev/null | grep -c Running)
  [ "$RUNNING" == "0" ] && break
  sleep 3
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# One snapshot of everything that decides whether this node has a pod network:
# what the kubelet thinks, what config is on disk, and which plugin binaries
# exist to run. Used in steps 1, 2 and 3 to watch the same three things change.
cat > /usr/local/bin/cnistate <<'WRAP'
#!/bin/bash
echo "=== node Ready condition ==="
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .status.conditions[?(@.type=="Ready")]}{.status}{"\t"}{.reason}{"\n"}  message: {.message}{"\n"}{end}{end}'
echo
echo "=== /etc/cni/net.d (the kubelet reads this) ==="
if [ -z "$(ls -A /etc/cni/net.d 2>/dev/null)" ]; then
  echo "  (empty -- no network configuration for the kubelet to use)"
else
  ls -1 /etc/cni/net.d
fi
echo
echo "=== /opt/cni/bin (the plugin binaries it would run) ==="
ls -1 /opt/cni/bin 2>/dev/null | tr '\n' ' '
echo
WRAP
chmod +x /usr/local/bin/cnistate

# One HTTP request to the web Service from a throwaway Pod, printing the
# backend that answered and the exit code. Proves the Service path end to end
# without depending on anything already running inside the cluster.
cat > /usr/local/bin/websvc <<'WRAP'
#!/bin/bash
kubectl delete pod svccheck --ignore-not-found --wait=true >/dev/null 2>&1
kubectl run svccheck --restart=Never --image=registry.k8s.io/e2e-test-images/agnhost:2.53 \
  --command -- /bin/sh -c 'wget -qO- -T5 http://web/hostname; RC=$?; echo; echo "exit code: $RC"' >/dev/null 2>&1
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/svccheck --timeout=60s >/dev/null 2>&1
kubectl logs svccheck 2>&1
kubectl delete pod svccheck --ignore-not-found --wait=false >/dev/null 2>&1
WRAP
chmod +x /usr/local/bin/websvc

touch /tmp/.initfinished
