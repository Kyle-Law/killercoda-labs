
Liveness kills things. Readiness does something completely different — and the easiest way to believe it is to watch a Pod fail its readiness probe and *not* get restarted.

Deploy three replicas behind a Service:

```plain
kubectl apply -f - <<'YAML'
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
        livenessProbe:
          httpGet:
            path: /healthz
            port: 9898
          periodSeconds: 10
          failureThreshold: 3
---
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  type: NodePort
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 9898
    nodePort: 30080
YAML
kubectl rollout status deployment/web --timeout=120s
```{{exec}}

podinfo can be told to start failing its own readiness check, at runtime, with a `POST` to `/readyz/disable`. **Break readiness on exactly one of the three Pods.**

Then predict, before checking: does that Pod restart? Does it stay `Running`? Does it still receive traffic?

<br>

<details><summary>Tip</summary>

Pick one Pod by name and `exec` the request inside it, so only that replica is affected:

```plain
kubectl get pods -l app=web
```{{exec}}

The three things worth looking at afterwards are the Pod's `READY` and `RESTARTS` columns, the Service's `EndpointSlice`, and where requests actually land.

</details>

<details><summary>Solution</summary>

```plain
POD=$(kubectl get pod -l app=web -o jsonpath='{.items[0].metadata.name}')
echo "breaking readiness on $POD"
kubectl exec $POD -- wget -qO- --post-data='' localhost:9898/readyz/disable
```{{exec}}

Give the probe a few seconds to fail twice, then look:

```plain
sleep 10
kubectl get pods -l app=web
```{{exec}}

One Pod is `0/1` — but it is still **`Running`**, and its `RESTARTS` count is still **`0`**. Nothing killed it. Compare that against step 1, where a failing *liveness* probe produced `SIGKILL` and an ever-climbing restart count. Same failing HTTP endpoint, entirely different consequence.

```plain
kubectl get endpointslice -l kubernetes.io/service-name=web \
  -o jsonpath='{range .items[0].endpoints[*]}{.addresses[0]}  ready={.conditions.ready}{"\n"}{end}'
```{{exec}}

Two `ready=true`, one `ready=false`. That flag is the whole mechanism: kube-proxy only forwards to ready endpoints.

```plain
for i in $(seq 1 20); do curl -s http://localhost:30080/ | grep -o '"hostname": "[^"]*"'; done | sort | uniq -c
```{{exec}}

Twenty requests, two hostnames, zero to the unready Pod. The application is still running and still reachable directly by IP — Kubernetes simply stopped sending it Service traffic, which is precisely what you want while a replica is warming a cache, reloading config, or waiting on a dependency.

</details>
