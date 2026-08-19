
Create a `PersistentVolumeClaim` named `dynamic-pvc`:

- requests `200Mi` of storage
- access mode `ReadWriteOnce`
- **do not** set `storageClassName` — let the default StorageClass provision the volume for you

Confirm it reaches `STATUS Bound` and that a `PersistentVolume` was created for it.

<br>

<details><summary>Tip</summary>

```
kubectl explain pvc.spec
```{{exec}}

```
kubectl get pvc,pv
```{{exec}}

</details>

<details><summary>Solution</summary>

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 200Mi
EOF
```{{exec}}

```
kubectl get pvc dynamic-pvc
```{{exec}}

</details>
