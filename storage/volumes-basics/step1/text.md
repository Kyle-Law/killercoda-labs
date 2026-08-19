
Create a Pod named `shared-data` with **two containers** sharing a single `emptyDir` volume mounted at `/data` in both:

- container `writer` (image `busybox`) — writes the text `hello-from-writer` into `/data/message.txt`, then sleeps so the Pod keeps running
- container `reader` (image `busybox`) — just sleeps, so you can exec into it afterwards

Confirm you can `exec` into `reader` and read the file that `writer` wrote.

<br>

<details><summary>Tip</summary>

```
kubectl explain pod.spec.volumes.emptyDir
```{{exec}}

A container's `command` can be something like `["sh", "-c", "<your commands> && sleep 3600"]`.

</details>

<details><summary>Solution</summary>

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: shared-data
spec:
  containers:
  - name: writer
    image: busybox
    command: ["sh", "-c", "echo hello-from-writer > /data/message.txt && sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  - name: reader
    image: busybox
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    emptyDir: {}
EOF
```{{exec}}

```
kubectl exec shared-data -c reader -- cat /data/message.txt
```{{exec}}

</details>
