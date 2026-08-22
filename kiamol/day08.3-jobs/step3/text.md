
Jobs sometimes hang. Create a Job named `capped-job` whose container would otherwise run forever (`sleep 3600`), but enforce a hard **10-second** wall-clock limit using `activeDeadlineSeconds`, so it gets killed automatically and marked `Failed` with reason `DeadlineExceeded` — instead of running indefinitely.

<br>

<details><summary>Tip</summary>

```
kubectl explain job.spec.activeDeadlineSeconds
```{{exec}}

`activeDeadlineSeconds` counts wall-clock time across the Job's **entire** run, including retries — a different failure mode from `backoffLimit`, which counts individual failed attempts. (`ttlSecondsAfterFinished` is a related field worth knowing about too, for auto-cleaning up finished Jobs — not needed for this task.)

</details>

<details><summary>Solution</summary>

```
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: capped-job
spec:
  activeDeadlineSeconds: 10
  template:
    spec:
      containers:
      - name: worker
        image: busybox
        command: ["sh", "-c", "sleep 3600"]
      restartPolicy: Never
EOF
```{{exec}}

```
kubectl get job capped-job --watch
```{{exec}}

</details>
