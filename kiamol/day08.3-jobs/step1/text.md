
Job `broken-job` never completes — it's already exceeded its `backoffLimit` and given up, with failed Pods left behind as evidence (each retry under `restartPolicy: Never` is a brand-new Pod, not a restarted container).

Find out why they're failing, then fix the Job so a run actually succeeds. A Job's Pod template can't be edited in place — you'll need to delete and recreate it.

<br>

<details><summary>Tip</summary>

```
kubectl get pods -l job-name=broken-job
kubectl logs -l job-name=broken-job --all-containers
kubectl describe job broken-job
```{{exec}}

</details>

<details><summary>Solution</summary>

```
kubectl delete job broken-job
```{{exec}}

```
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: broken-job
spec:
  backoffLimit: 1
  template:
    spec:
      containers:
      - name: worker
        image: busybox
        command: ["sh", "-c", "exit 0"]
      restartPolicy: Never
EOF
```{{exec}}

```
kubectl wait --for=condition=complete job/broken-job --timeout=60s
```{{exec}}

</details>
