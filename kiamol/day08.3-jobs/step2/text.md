
Create a Job named `batch-job` that runs to **5 total completions**, with at most **2 Pods running in parallel** at any time. Each Pod should just sleep a few seconds and exit successfully — e.g. `sleep 5`.

Watch it run: you should see Pods complete in waves of (at most) 2, not all 5 at once and not one at a time.

<br>

<details><summary>Tip</summary>

```
kubectl explain job.spec.completions
kubectl explain job.spec.parallelism
```{{exec}}

```
kubectl get pods -l job-name=batch-job --watch
```{{exec}}

</details>

<details><summary>Solution</summary>

```
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: batch-job
spec:
  completions: 5
  parallelism: 2
  template:
    spec:
      containers:
      - name: worker
        image: busybox
        command: ["sh", "-c", "sleep 5"]
      restartPolicy: Never
EOF
```{{exec}}

```
kubectl wait --for=condition=complete job/batch-job --timeout=120s
kubectl get job batch-job
```{{exec}}

</details>
