
Create a `PersistentVolumeClaim` named `static-pvc` that requests `100Mi` with access mode `ReadWriteOnce` and `storageClassName: manual` — matching `static-pv` so it binds to that specific volume instead of triggering the cluster's default dynamic provisioner.

Confirm it reaches `STATUS Bound` and is bound to `static-pv`.

<br>

<details><summary>Tip</summary>

A PVC only binds to a PV whose `storageClassName`, access modes, and capacity are compatible. Leaving `storageClassName` unset here would trigger dynamic provisioning instead of binding to your PV.

</details>

<details><summary>Solution</summary>

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: static-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: manual
  resources:
    requests:
      storage: 100Mi
EOF
```{{exec}}

```
kubectl get pvc static-pvc
```{{exec}}

</details>
