
Clear the node one more time:

```plain
kubectl delete deployment research inference
```{{exec}}

Distributed training is **all-or-nothing**: a 3-worker job with only 2 workers scheduled does no work at all. The workers rendezvous at startup and block until every peer is present.

The default Kubernetes scheduler doesn't know that. It places Pods **one at a time**, taking whatever it can get.

Submit two training jobs that each need **3** GPUs, onto a node with **4**, and watch what happens.

<br>

<details><summary>Tip</summary>

Model each job as a Deployment with 3 replicas, 1 GPU each, whose containers just sleep — standing in for workers blocked at the rendezvous, holding their GPU and waiting.

</details>

<details><summary>Solution</summary>

```plain
for job in job-a job-b; do
cat <<YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $job
spec:
  replicas: 3
  selector:
    matchLabels:
      app: $job
  template:
    metadata:
      labels:
        app: $job
        role: training
    spec:
      containers:
        - name: worker
          image: busybox:1.36
          command: ["sh", "-c", "sleep 3600"]
          resources:
            limits:
              nvidia.com/gpu: 1
YAML
done
```{{exec}}

```plain
sleep 15
kubectl get pods -l role=training
```{{exec}}

Count what you have:

```plain
echo "job-a running: $(kubectl get pods -l app=job-a --no-headers | grep -c Running)"
echo "job-b running: $(kubectl get pods -l app=job-b --no-headers | grep -c Running)"
echo "pending:       $(kubectl get pods -l role=training --no-headers | grep -c Pending)"
```{{exec}}

</details>

<br>

## What you're looking at

Each job holds **2 of the 3** GPUs it needs. All four accelerators are allocated. Neither job can start. Neither will release anything, because from Kubernetes' point of view both Deployments are healthy and progressing.

**This is a permanent deadlock producing zero work at 100% GPU allocation** — and no component in the cluster considers it an error.

<details><summary>Info: the fix, and why it's a whole product category</summary>

The missing concept is **gang scheduling** — admit all a job's Pods or none of them.

That's what [Kueue](https://kueue.sigs.k8s.io/) and [Volcano](https://volcano.sh/) exist to provide. They hold jobs in a queue and only admit one when its *entire* resource requirement can be satisfied at once. Job A would run to completion, then Job B. Total time is the same; the difference is that work actually finishes.

It's also why AI platform teams rarely let users submit Deployments directly to a shared GPU pool. The deadlock above is trivially easy to cause by accident, and nothing warns you.

</details>
