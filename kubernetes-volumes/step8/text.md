
Create a Pod named `dynamic-pod` (any image works, e.g. `busybox` with a long-running command) that mounts `dynamic-pvc` at `/data`. Exec into it and write something to a file under `/data` to prove the mount works.

Then **delete both the Pod and the PVC**, and check whether the `PersistentVolume` that was dynamically created for `dynamic-pvc` is still around afterwards.

<br>

<details><summary>Tip</summary>

Dynamically provisioned volumes carry a default `persistentVolumeReclaimPolicy` — check it on the PV before you delete anything:

```
kubectl get pv -o custom-columns=NAME:.metadata.name,RECLAIM:.spec.persistentVolumeReclaimPolicy
```{{exec}}

</details>

<details><summary>Solution</summary>

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: dynamic-pod
spec:
  containers:
  - name: busybox
    image: busybox
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: dynamic-pvc
EOF
```{{exec}}

```
kubectl exec dynamic-pod -- sh -c "echo hello > /data/file.txt"
kubectl exec dynamic-pod -- cat /data/file.txt
```{{exec}}

```
kubectl delete pod dynamic-pod
kubectl delete pvc dynamic-pvc
kubectl get pv
```{{exec}}

The `PersistentVolume` is gone. Dynamically provisioned volumes default to reclaim policy `Delete`, so the underlying storage is removed as soon as the claim goes away — unlike a statically created PV, which you'd typically set to `Retain`.

</details>
