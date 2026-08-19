
On the node's own filesystem, create the directory `/mnt/hostpath-demo` containing a file `index.html` with the exact contents `served-from-host`.

Then create a Pod named `hostpath-pod` (image `nginx:stable-alpine`) that mounts that host directory at `/usr/share/nginx/html` using a `hostPath` volume. Confirm nginx is serving the file by reading it from inside the container.

<br>

<details><summary>Tip</summary>

```
kubectl explain pod.spec.volumes.hostPath
```{{exec}}

Setting `type: Directory` on the hostPath volume makes Kubernetes verify the directory already exists before it'll start the Pod.

</details>

<details><summary>Solution</summary>

```
mkdir -p /mnt/hostpath-demo
echo "served-from-host" > /mnt/hostpath-demo/index.html
```{{exec}}

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-pod
spec:
  containers:
  - name: nginx
    image: nginx:stable-alpine
    volumeMounts:
    - name: host-vol
      mountPath: /usr/share/nginx/html
  volumes:
  - name: host-vol
    hostPath:
      path: /mnt/hostpath-demo
      type: Directory
EOF
```{{exec}}

```
kubectl exec hostpath-pod -- cat /usr/share/nginx/html/index.html
```{{exec}}

</details>
