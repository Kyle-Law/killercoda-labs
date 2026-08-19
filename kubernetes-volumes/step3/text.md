
Create the directory `/mnt/static-pv-data` on the node, then create a `PersistentVolume` named `static-pv` with:

- capacity `100Mi`
- access mode `ReadWriteOnce`
- `storageClassName: manual`
- `hostPath.path: /mnt/static-pv-data`
- `persistentVolumeReclaimPolicy: Retain`

Confirm it shows up with `STATUS Available`.

<br>

<details><summary>Tip</summary>

```
kubectl explain pv.spec
```{{exec}}

Setting a `storageClassName` that no dynamic provisioner matches (like `manual`) keeps this PV from being auto-claimed by anything other than a PVC that asks for that same class.

</details>

<details><summary>Solution</summary>

```
mkdir -p /mnt/static-pv-data
```{{exec}}

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: static-pv
spec:
  capacity:
    storage: 100Mi
  accessModes:
    - ReadWriteOnce
  storageClassName: manual
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /mnt/static-pv-data
EOF
```{{exec}}

```
kubectl get pv static-pv
```{{exec}}

</details>
