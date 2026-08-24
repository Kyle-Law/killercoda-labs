
Prometheus discovers what to scrape by querying the Kubernetes API for Pods, Services, Endpoints and Nodes across the cluster. That's the **Prometheus server's** own permissions — separate from the operator's, which only needs to manage custom resources.

Before deploying Prometheus, set up its identity:

- a ServiceAccount named `prometheus` in the `default` namespace
- a ClusterRole named `prometheus` granting `get`, `list`, `watch` on `nodes`, `nodes/metrics`, `services`, `endpoints`, and `pods` (core API group), plus `get` on the non-resource URL `/metrics`
- a ClusterRoleBinding named `prometheus` tying them together

Cluster-scoped, not namespaced — Prometheus needs to see targets across the whole cluster, including Nodes, which aren't namespaced at all.

<br>

<details><summary>Tip</summary>

```
kubectl create serviceaccount --help
kubectl explain clusterrole.rules
```{{exec}}

`nonResourceURLs` can't be expressed with `kubectl create clusterrole --verb=... --resource=...` alone — write the ClusterRole as YAML.

</details>

<details><summary>Solution</summary>

```
kubectl create serviceaccount prometheus
```{{exec}}

```
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/metrics
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
EOF
```{{exec}}

```
kubectl create clusterrolebinding prometheus --clusterrole=prometheus --serviceaccount=default:prometheus
```{{exec}}

```
kubectl auth can-i list pods --as=system:serviceaccount:default:prometheus --all-namespaces
```{{exec}}

</details>
