
Reset to a clean pool:

```plain
kubectl delete namespace team-a team-b --wait=true
```{{exec}}

Now the situation every GPU cluster lives with: cheap experimental work fills the accelerators, then something important needs them *now*.

**1.** Create two PriorityClasses — `research` (value `100`) and `production` (value `1000000`).

**2.** Deploy `research` at **4 replicas**, 1 GPU each, at the low priority. It takes the whole node.

**3.** Deploy `inference` needing **2** GPUs at the high priority — and watch the scheduler take them back.

<br>

<details><summary>Info: preemption, briefly</summary>

When a Pod can't schedule, the scheduler checks whether evicting lower-priority Pods would make room. If so it deletes them and places the higher-priority Pod.

This is what makes a shared GPU cluster economically viable: you let researchers saturate idle capacity, knowing production can reclaim it within seconds rather than waiting for someone's job to finish.

The evicted Pods aren't gone for good — their Deployment recreates them, and they go `Pending` until capacity frees up. Preemption reorders access; it doesn't cancel work.

</details>

<details><summary>Tip</summary>

```plain
kubectl get priorityclass
kubectl get events --sort-by=.lastTimestamp | grep -i preempt
```{{exec}}

`preemptionPolicy` defaults to `PreemptLowerPriority`, so you don't need to set it — but the Pod spec does need `priorityClassName`.

</details>

<details><summary>Solution</summary>

```plain
cat <<'YAML' | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: research
value: 100
globalDefault: false
description: "Best-effort experimental work, preemptible"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: production
value: 1000000
globalDefault: false
description: "Production inference, preempts research"
YAML
```{{exec}}

Fill the node with low-priority work:

```plain
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: research
spec:
  replicas: 4
  selector:
    matchLabels:
      app: research
  template:
    metadata:
      labels:
        app: research
    spec:
      priorityClassName: research
      containers:
        - name: research
          image: busybox:1.36
          command: ["sh", "-c", "sleep 3600"]
          resources:
            limits:
              nvidia.com/gpu: 1
YAML
```{{exec}}

```plain
kubectl wait --for=condition=Ready pod -l app=research --timeout=90s
kubectl get pods -l app=research
```{{exec}}

All four GPUs are taken. Now production arrives:

```plain
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inference
spec:
  replicas: 2
  selector:
    matchLabels:
      app: inference
  template:
    metadata:
      labels:
        app: inference
    spec:
      priorityClassName: production
      containers:
        - name: inference
          image: busybox:1.36
          command: ["sh", "-c", "sleep 3600"]
          resources:
            limits:
              nvidia.com/gpu: 1
YAML
```{{exec}}

```plain
sleep 20
kubectl get pods -l app=inference
kubectl get pods -l app=research
```{{exec}}

Two research Pods were evicted; two are now `Pending`. Production is running. The eviction is in the events:

```plain
kubectl get events --sort-by=.lastTimestamp | grep -i preempt | tail -5
```{{exec}}

</details>
