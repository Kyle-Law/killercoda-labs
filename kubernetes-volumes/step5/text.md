
Create a Pod named `pv-pod` (image `nginx:stable-alpine`) that mounts `static-pvc` at `/usr/share/nginx/html`.

Once it's running, write the text `data-survives` into `/usr/share/nginx/html/index.html` inside the container. Then **delete the Pod entirely and recreate it** with the same definition. Confirm the file and its content are still there after the Pod comes back — proving the data lived in the PV, not in the Pod.

<br>

<details><summary>Tip</summary>

```
kubectl explain pod.spec.volumes.persistentVolumeClaim
```{{exec}}

</details>

<details><summary>Solution</summary>

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pv-pod
spec:
  containers:
  - name: nginx
    image: nginx:stable-alpine
    volumeMounts:
    - name: pv-vol
      mountPath: /usr/share/nginx/html
  volumes:
  - name: pv-vol
    persistentVolumeClaim:
      claimName: static-pvc
EOF
```{{exec}}

```
kubectl exec pv-pod -- sh -c "echo data-survives > /usr/share/nginx/html/index.html"
```{{exec}}

```
kubectl delete pod pv-pod
```{{exec}}

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pv-pod
spec:
  containers:
  - name: nginx
    image: nginx:stable-alpine
    volumeMounts:
    - name: pv-vol
      mountPath: /usr/share/nginx/html
  volumes:
  - name: pv-vol
    persistentVolumeClaim:
      claimName: static-pvc
EOF
```{{exec}}

```
kubectl exec pv-pod -- cat /usr/share/nginx/html/index.html
```{{exec}}

</details>
