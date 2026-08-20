
Create a Pod named `multi-pod` with two containers sharing a single `emptyDir` volume, but at different access levels:

- container `writer` (image `busybox`, long-running command) mounts the volume at `/data-rw`, writable
- container `reader` (image `busybox`, long-running command) mounts the **same** volume at `/data-ro`, read-only

Confirm `writer` can create a file that `reader` can see — and that `reader` genuinely can't write back.

<br>

<details><summary>Tip</summary>

```
kubectl logs multi-pod
```{{exec}}

That fails — a multicontainer Pod has no single log stream; you need `-c <container-name>` on every `logs`/`exec` command.

</details>

<details><summary>Solution</summary>

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: multi-pod
spec:
  containers:
  - name: writer
    image: busybox
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data-rw
  - name: reader
    image: busybox
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data-ro
      readOnly: true
  volumes:
  - name: data
    emptyDir: {}
EOF
```{{exec}}

```
kubectl exec multi-pod -c writer -- sh -c "echo hello > /data-rw/test.txt"
kubectl exec multi-pod -c reader -- cat /data-ro/test.txt
kubectl exec multi-pod -c reader -- sh -c "echo bad >> /data-ro/test.txt"
```{{exec}}

The last command fails with `Read-only file system` — same volume, different mount, different rules.

</details>
