
Now submit the same two 3-GPU jobs — but through the queue.

Two things make a job Kueue-managed:

- the label `kueue.x-k8s.io/queue-name: team-queue`
- `suspend: true` in the spec, so it starts held

<br>

<details><summary>Solution</summary>

```plain
for job in job-a job-b; do
cat <<YAML | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: $job
  labels:
    kueue.x-k8s.io/queue-name: team-queue
spec:
  parallelism: 3
  completions: 3
  suspend: true
  template:
    spec:
      containers:
        - name: worker
          image: busybox:1.36
          command: ["sh", "-c", "sleep 60"]
          resources:
            limits:
              nvidia.com/gpu: 1
      restartPolicy: Never
YAML
done
```{{exec}}

Look at what Kueue did:

```plain
sleep 15
kubectl get jobs
kubectl get pods -l role=training 2>/dev/null; kubectl get pods
```{{exec}}

```plain
kubectl get workloads
```{{exec}}

</details>

<br>

## What changed

One job is running with **all three** of its workers. The other is still `suspend: true` with **zero** Pods — Kueue is holding it, because admitting it would need 6 GPUs out of a 4-GPU quota.

Compare that with step 1: the same two jobs, the same cluster, but instead of both jamming at 2/3 workers forever, one runs to completion.

```plain
kubectl get workloads -o custom-columns=NAME:.metadata.name,ADMITTED:.status.conditions[?\(@.type==\"Admitted\"\)].status
```{{exec}}

Wait for the first job to finish and watch the second start on its own:

```plain
kubectl wait --for=condition=complete job --all --timeout=300s
kubectl get jobs
```{{exec}}

<br>

<details><summary>Info: same total time, completely different outcome</summary>

Kueue didn't make anything faster. Both jobs still need 3 GPUs, and the cluster still has 4, so they still run one after the other.

The difference is that **work finishes**. In step 1 the total throughput was zero, permanently. Here it's two completed jobs, sequentially, with no human intervention.

That's the entire value proposition of gang scheduling: it doesn't add capacity, it stops you from destroying the capacity you have.

</details>
