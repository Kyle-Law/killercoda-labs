
`risky-pod` mounts the **entire node's root filesystem** at `/host` — a serious security exposure. Confirm it yourself first: `kubectl exec risky-pod -- cat /host/etc/hostname` shows you the *node's* hostname file, not the container's.

Fix `risky-pod` by replacing its volume with the same safe pattern from the previous step: a `hostPath` on `/var/log` with `subPath: app-a`, mounted at `/mounted`. It should end up able to read `/mounted/marker.txt` and nothing else on the node.

<br>

<details><summary>Tip</summary>

`volumes` isn't a field you can patch on a live Pod — get its YAML, edit it, delete the Pod, reapply.

```
kubectl get pod risky-pod -o yaml > /root/risky-pod.yaml
```{{exec}}

</details>

<details><summary>Solution</summary>

```
kubectl delete pod risky-pod
```{{exec}}

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: risky-pod
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
kubectl exec risky-pod -- cat /mounted/marker.txt
```{{exec}}

</details>
