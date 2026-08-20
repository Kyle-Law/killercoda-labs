
A DaemonSet named `node-agent` is running (1 Pod, since this cluster has one node). Delete the DaemonSet **without** deleting its Pod. Confirm the Pod is still running, now with no owner. Then recreate the exact same DaemonSet — confirm it **adopts** the existing orphaned Pod rather than creating a new one: same Pod name, `RESTARTS` still 0.

<br>

<details><summary>Tip</summary>

```
kubectl delete daemonset --help
```{{exec}}

The old `--cascade=false` flag still works in most kubectl versions but is deprecated — `--cascade=orphan` is the current spelling for the same thing.

</details>

<details><summary>Solution</summary>

```
kubectl delete daemonset node-agent --cascade=orphan
kubectl get pod -l app=node-agent
```{{exec}}

The Pod is still there, with no controller managing it.

```
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-agent
spec:
  selector:
    matchLabels:
      app: node-agent
  template:
    metadata:
      labels:
        app: node-agent
    spec:
      containers:
      - name: agent
        image: busybox
        command: ["sh", "-c", "sleep 3600"]
EOF
```{{exec}}

```
kubectl get pod -l app=node-agent -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount,OWNER:.metadata.ownerReferences[0].name
```{{exec}}

Same Pod, adopted — the DaemonSet's label selector matched an existing Pod, so it didn't need to create a new one.

</details>
