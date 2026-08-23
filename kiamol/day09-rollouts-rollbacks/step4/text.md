
`web-blue` is running, and Service `web-bg` currently routes to it. This is a blue/green release — the one pattern a Deployment doesn't give you for free.

Create a `web-green` Deployment: same `app: web-bg` label, but `version: green`, image `nginx:1.26-alpine`, 2 replicas. Once it's healthy, flip the `web-bg` Service to route to `green` instead of `blue` — a Service's `selector` is mutable, no need to touch anything else about it.

Confirm `web-blue` is still running afterward, completely untouched — that's the whole point: it stays warm as an instant rollback target.

<br>

<details><summary>Tip</summary>

```
kubectl get svc web-bg -o yaml | grep -A2 selector
```{{exec}}

Deleting `web-blue` after the flip would defeat the entire pattern — don't.

</details>

<details><summary>Solution</summary>

```
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-green
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-bg
      version: green
  template:
    metadata:
      labels:
        app: web-bg
        version: green
    spec:
      containers:
      - name: web
        image: nginx:1.26-alpine
EOF
```{{exec}}

```
kubectl wait --for=condition=Available deployment/web-green --timeout=60s
```{{exec}}

```
kubectl patch service web-bg --type merge -p '{"spec":{"selector":{"app":"web-bg","version":"green"}}}'
```{{exec}}

```
kubectl get endpoints web-bg
kubectl get deployment web-blue web-green
```{{exec}}

</details>
