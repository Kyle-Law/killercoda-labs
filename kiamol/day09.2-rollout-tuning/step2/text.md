
`shop-v1` runs 5 replicas behind Service `shop`. Notice the Service selects on `app: shop` only — it deliberately ignores `version`, so it will pick up **any** Pod carrying that app label.

Release `nginx:1.26-alpine` as a **20% canary**: create a `shop-v2` Deployment so that exactly 1 of the 5 Pods behind the Service is v2 — without increasing total capacity, and without touching the Service at all.

<br>

<details><summary>Tip</summary>

```
kubectl get endpoints shop
kubectl get pods -l app=shop --show-labels
```{{exec}}

There's no traffic-weighting field anywhere here — the "percentage" is just the ratio of Pods behind one Service. Keeping the total at 5 means v1 has to give up a replica for v2 to take one.

</details>

<details><summary>Solution</summary>

```
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop-v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: shop
      version: v2
  template:
    metadata:
      labels:
        app: shop
        version: v2
    spec:
      containers:
      - name: shop
        image: nginx:1.26-alpine
EOF
```{{exec}}

```
kubectl scale deployment shop-v1 --replicas=4
```{{exec}}

```
kubectl get endpoints shop
kubectl get pods -l app=shop --show-labels
```{{exec}}

Five endpoints, one of them v2 — a 20% canary. Widening it is just `kubectl scale` on both Deployments.

</details>
