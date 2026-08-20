
Two directories already exist on the node, side by side: `/var/log/app-a` and `/var/log/app-b`, each with a `marker.txt`.

Create a Pod named `scoped-pod` (image `busybox`, long-running command) that can read `/var/log/app-a/marker.txt` — mounted at `/mounted/marker.txt` — but has **no way to reach** `/var/log/app-b`, even though both live under the same `hostPath` root. Use a single `hostPath` volume on `/var/log` with a `subPath` to restrict it.

<br>

<details><summary>Tip</summary>

```
kubectl explain pod.spec.containers.volumeMounts.subPath
```{{exec}}

`subPath` is a field on the **mount**, not the volume — the volume can point at a broad path, and `subPath` narrows what the container actually sees.

</details>

<details><summary>Solution</summary>

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: scoped-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: node-log
      mountPath: /mounted
      subPath: app-a
  volumes:
  - name: node-log
    hostPath:
      path: /var/log
      type: Directory
EOF
```{{exec}}

```
kubectl exec scoped-pod -- cat /mounted/marker.txt
kubectl exec scoped-pod -- ls /mounted
```{{exec}}

</details>
