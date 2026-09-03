
Confirm the node's accelerators:

```plain
kubectl describe node $(cat /root/nodename) | grep -A9 "^Capacity:"
```{{exec}}

Four GPUs. Now submit two training jobs that each need **three** workers, modelled as Deployments whose containers block forever — standing in for workers waiting at a rendezvous, each holding its GPU.

<br>

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

```plain
echo "job-a running: $(kubectl get pods -l app=job-a --no-headers | grep -c Running)"
echo "job-b running: $(kubectl get pods -l app=job-b --no-headers | grep -c Running)"
echo "pending:       $(kubectl get pods -l role=training --no-headers | grep -c Pending)"
```{{exec}}

</details>

<br>

## The deadlock

Each job holds **2 of the 3** GPUs it needs. All four are allocated. Neither job can ever start, and neither will release anything — because as far as Kubernetes is concerned both Deployments are healthy and progressing.

Nothing in the cluster considers this an error. There is no event, no warning, and no timeout.

```plain
kubectl get deployments
```{{exec}}

Both report their Pods as expected. Now clean up, and fix it properly:

```plain
kubectl delete deployment job-a job-b
```{{exec}}
