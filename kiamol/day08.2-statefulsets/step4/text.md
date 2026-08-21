
Try to add a second `volumeClaimTemplate` named `logs` (5Mi) to the live `db` StatefulSet. Confirm the API server rejects the change outright (`Forbidden`).

`volumeClaimTemplates` isn't on the short list of fields you're allowed to change on an existing StatefulSet (`replicas`, `template`, `updateStrategy` are). The only way to change it is to delete and recreate the StatefulSet — and deleting a StatefulSet does **not** delete its PVCs.

Delete `db`, then recreate it with two claim templates (`data` and `logs`, both mounted, 2 replicas). Confirm `db-1` reattaches to the existing `data-db-1` PVC — the data you wrote back in an earlier step is still there.

<br>

<details><summary>Tip</summary>

```
kubectl get pvc
```{{exec}}

Deleting the StatefulSet itself won't touch what this shows.

</details>

<details><summary>Solution</summary>

Confirm the rejection first:

```
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db
spec:
  serviceName: db
  replicas: 3
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
      - name: db
        image: busybox
        command: ["sh", "-c", "sleep 3600"]
        volumeMounts:
        - name: data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 10Mi
  - metadata:
      name: logs
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 5Mi
EOF
```{{exec}}

That fails with `Forbidden`. Delete and recreate instead:

```
kubectl delete statefulset db
```{{exec}}

```
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db
spec:
  serviceName: db
  replicas: 2
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
      - name: db
        image: busybox
        command: ["sh", "-c", "sleep 3600"]
        volumeMounts:
        - name: data
          mountPath: /data
        - name: logs
          mountPath: /logs
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 10Mi
  - metadata:
      name: logs
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 5Mi
EOF
```{{exec}}

```
kubectl wait --for=condition=Ready pod/db-1 --timeout=60s
kubectl exec db-1 -- cat /data/marker.txt
```{{exec}}

</details>
