
Four GPUs exist. Find out how differently the scheduler treats them from CPU.

**1.** Create a Deployment named `trainer` requesting **1 GPU per Pod**, and scale it to **4**. All four should run.

**2.** Scale to **5**. The fifth Pod cannot schedule — capture its scheduling failure reason into `/root/pending-reason`.

<br>

<details><summary>Info: three rules that don't apply to CPU</summary>

- **Integers only.** `nvidia.com/gpu: 0.5` is rejected. You cannot have half a GPU; there is no time-slicing at this layer.
- **No overcommit.** If you set `limits`, they must equal `requests`. CPU lets you request 100m and burst higher; a GPU is assigned to you exclusively.
- **Specify it in `limits` or `requests` and Kubernetes fills in the other.** They are always equal, so you usually just write `limits`.

The practical consequence: a GPU cluster runs at whatever utilisation your *requests* imply. There is no bin-packing slack to reclaim, which is why GPU utilisation is such a persistent operational problem.

</details>

<details><summary>Tip</summary>

```plain
kubectl get pods -o wide
kubectl describe pod <pending-pod>
```{{exec}}

The scheduler records why it couldn't place a Pod in that Pod's Events.

</details>

<details><summary>Solution</summary>

```plain
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: trainer
spec:
  replicas: 4
  selector:
    matchLabels:
      app: trainer
  template:
    metadata:
      labels:
        app: trainer
    spec:
      containers:
        - name: trainer
          image: busybox:1.36
          command: ["sh", "-c", "sleep 3600"]
          resources:
            limits:
              nvidia.com/gpu: 1
YAML
```{{exec}}

```plain
kubectl wait --for=condition=Ready pod -l app=trainer --timeout=90s
kubectl get pods -l app=trainer
```{{exec}}

All four are running, and the node's GPUs are now fully allocated. Ask for a fifth:

```plain
kubectl scale deployment trainer --replicas=5
```{{exec}}

```plain
sleep 5
kubectl get pods -l app=trainer
```{{exec}}

One Pod is `Pending`. Find out why:

```plain
kubectl describe pod $(kubectl get pods -l app=trainer --field-selector=status.phase=Pending -o jsonpath='{.items[0].metadata.name}') \
  | grep -A3 Events | tee /root/pending-reason
```{{exec}}

`Insufficient nvidia.com/gpu` — the scheduler has nowhere to put it.

</details>

<details><summary>Try the rules yourself</summary>

Both of these are rejected outright:

```plain
kubectl run frac --image=busybox:1.36 --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"frac","image":"busybox:1.36","resources":{"limits":{"nvidia.com/gpu":"0.5"}}}]}}' \
  --command -- sleep 60
```{{exec}}

```plain
kubectl run mismatch --image=busybox:1.36 --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"mismatch","image":"busybox:1.36","resources":{"requests":{"nvidia.com/gpu":"1"},"limits":{"nvidia.com/gpu":"2"}}}]}}' \
  --command -- sleep 60
```{{exec}}

</details>
