
Deployment `spread-app` wants 2 replicas, but only 1 ever becomes `Ready` — the other sits `Pending` indefinitely. Find out why, then fix the Deployment so both replicas run (even though, on this cluster, they'll end up on the same node).

<br>

<details><summary>Tip</summary>

```
kubectl get pods -l app=spread-app -o wide
kubectl describe pod -l app=spread-app
kubectl get deployment spread-app -o yaml | grep -A10 affinity
```{{exec}}

Check the pending Pod's `Events` for why the scheduler is rejecting it. `requiredDuringSchedulingIgnoredDuringExecution` is a hard constraint — it fails scheduling entirely if it can't be met.

</details>

<details><summary>Solution</summary>

Relax the constraint from required to preferred:

```
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spread-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: spread-app
  template:
    metadata:
      labels:
        app: spread-app
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: spread-app
              topologyKey: kubernetes.io/hostname
      containers:
      - name: app
        image: nginx:stable-alpine
EOF
```{{exec}}

```
kubectl get pods -l app=spread-app
```{{exec}}

</details>
