
One of the two nodes now carries a custom taint. Find out which, and what it is.

Create a DaemonSet named `infra-agent`, label `app: infra-agent`, image `busybox:1.28`, running a long-running command, that ends up running on **both** nodes — including the tainted one — without removing the taint itself.

<br>

<details><summary>Tip</summary>

```
kubectl describe nodes | grep -A1 Taints
```{{exec}}

```
kubectl explain pod.spec.tolerations
```{{exec}}

A `toleration` needs to match the taint's key, value, and effect exactly (or use `operator: Exists` to match the key regardless of value).

</details>

<details><summary>Solution</summary>

```
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: infra-agent
spec:
  selector:
    matchLabels:
      app: infra-agent
  template:
    metadata:
      labels:
        app: infra-agent
    spec:
      tolerations:
      - key: dedicated
        operator: Equal
        value: infra
        effect: NoSchedule
      containers:
      - name: agent
        image: busybox:1.28
        command: ["sh", "-c", "sleep 3600"]
EOF
```{{exec}}

```
kubectl get pod -l app=infra-agent -o wide
```{{exec}}

</details>
