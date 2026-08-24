
Now the payoff of the operator pattern: deploy Prometheus itself by creating a **custom resource**, not a StatefulSet.

Create a `Prometheus` resource (`apiVersion: monitoring.coreos.com/v1`) named `main` in `default` with:

- `replicas: 1`
- `serviceAccountName: prometheus` (the identity you just created)
- `serviceMonitorSelector: {}` — an empty selector, meaning "watch **all** ServiceMonitors in this namespace"

Then watch what the operator builds for you. You never write a StatefulSet — it appears, named `prometheus-main`, because the operator saw your custom resource and reconciled it into real objects.

<br>

<details><summary>Tip</summary>

```
kubectl explain prometheus.spec
```{{exec}}

```
kubectl get prometheus,statefulset,pods
```{{exec}}

An empty selector (`{}`) means "match everything", which is very different from omitting the field entirely (which can mean "match nothing").

</details>

<details><summary>Solution</summary>

```
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: main
spec:
  replicas: 1
  serviceAccountName: prometheus
  serviceMonitorSelector: {}
EOF
```{{exec}}

```
kubectl get prometheus main
kubectl get statefulset prometheus-main
kubectl rollout status statefulset/prometheus-main --timeout=300s
```{{exec}}

</details>
