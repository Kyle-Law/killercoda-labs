
There's no `kubectl create daemonset` command. Generate a Deployment manifest with `--dry-run=client -o yaml` as a starting point, then hand-edit it into a real DaemonSet.

Create a DaemonSet named `log-agent`, label `app: log-agent`, image `busybox`, running a long-running command (e.g. `sleep 3600`), that mounts the node's `/var/log` directory into the container at `/host-logs`, read-only, using a `hostPath` volume. Get it running on every node that currently accepts it.

<br>

<details><summary>Tip</summary>

```
kubectl create deployment log-agent --image=busybox --dry-run=client -o yaml
```{{exec}}

Take that output and change what needs to change: the `kind`, and drop anything that's Deployment-specific (`replicas`, `strategy`) — a DaemonSet's Pod template works exactly like any other controller's.

</details>

<details><summary>Solution</summary>

```
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-agent
spec:
  selector:
    matchLabels:
      app: log-agent
  template:
    metadata:
      labels:
        app: log-agent
    spec:
      containers:
      - name: agent
        image: busybox
        command: ["sh", "-c", "sleep 3600"]
        volumeMounts:
        - name: varlog
          mountPath: /host-logs
          readOnly: true
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
          type: Directory
EOF
```{{exec}}

```
kubectl get daemonset log-agent
kubectl get pod -l app=log-agent -o wide
```{{exec}}

</details>
