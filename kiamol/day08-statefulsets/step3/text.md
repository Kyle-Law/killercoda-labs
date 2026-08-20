
Create a StatefulSet named `data-app` (headless Service also named `data-app`, 2 replicas, `busybox` sleeping) that uses `volumeClaimTemplates` — **not** a shared PVC — so each replica gets its own independent storage: a claim named `data`, `10Mi`, `ReadWriteOnce`, mounted at `/data`.

Confirm each replica really does get its **own** PVC (`data-data-app-0` and `data-data-app-1`) by writing `zero` into `/data/marker.txt` on `data-app-0`, and confirming `data-app-1` does **not** see it.

<br>

<details><summary>Tip</summary>

```
kubectl explain statefulset.spec.volumeClaimTemplates
```{{exec}}

`volumeClaimTemplates` sits alongside `template` in the StatefulSet spec, not inside it.

</details>

<details><summary>Solution</summary>

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: data-app
spec:
  clusterIP: None
  selector:
    app: data-app
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: data-app
spec:
  serviceName: data-app
  replicas: 2
  selector:
    matchLabels:
      app: data-app
  template:
    metadata:
      labels:
        app: data-app
    spec:
      containers:
      - name: app
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
EOF
```{{exec}}

```
kubectl get pvc data-data-app-0 data-data-app-1
```{{exec}}

(PVCs from `volumeClaimTemplates` are named `<template-name>-<pod-name>` — they don't automatically inherit the Pod template's labels, so a label selector won't find them here.)

```
kubectl exec data-app-0 -- sh -c "echo zero > /data/marker.txt"
kubectl exec data-app-0 -- cat /data/marker.txt
kubectl exec data-app-1 -- cat /data/marker.txt
```{{exec}}

The last command fails — `data-app-1` has its own, empty volume.

</details>
