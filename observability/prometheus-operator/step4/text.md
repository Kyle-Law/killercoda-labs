
`sample-app` is running 2 replicas (spread across both nodes) behind a Service on port `9898`, exposing Prometheus metrics at `/metrics`. Prometheus doesn't know about it yet — nothing has told it to scrape.

Create a `ServiceMonitor` named `sample-app` that selects the `sample-app` Service (by its `app: sample-app` label) and scrapes its `http` port. Because your `Prometheus` resource uses an empty `serviceMonitorSelector`, it'll pick this up automatically — no Prometheus restart, no config file to edit.

Confirm Prometheus is actually scraping both Pods by querying its own API for active targets.

<br>

<details><summary>Tip</summary>

```
kubectl explain servicemonitor.spec
kubectl explain servicemonitor.spec.endpoints
```{{exec}}

A ServiceMonitor's `endpoints[].port` refers to the **Service's port name**, not a raw number.

To query Prometheus directly, port-forward it:

```
kubectl port-forward svc/prometheus-operated 9090:9090 &
curl -s "http://localhost:9090/api/v1/targets?state=active" | head -c 500
```{{exec}}

</details>

<details><summary>Solution</summary>

```
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: sample-app
spec:
  selector:
    matchLabels:
      app: sample-app
  endpoints:
  - port: http
EOF
```{{exec}}

Give Prometheus a moment to reload its config and complete a scrape cycle, then:

```
kubectl port-forward svc/prometheus-operated 9090:9090 &
sleep 3
curl -s "http://localhost:9090/api/v1/targets?state=active" | grep -o '"health":"up"' | wc -l
```{{exec}}

Two healthy targets — one per Pod.

</details>
