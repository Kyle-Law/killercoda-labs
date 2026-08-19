
Create a generic `Secret` named `app-secret` with a single key `password` whose value is `s3cr3t`.

Then create a Pod named `secret-pod` (image `busybox`, long-running command) that mounts `app-secret` as a volume at `/etc/secret`. Confirm `/etc/secret/password` contains `s3cr3t`, and check the file's permission bits — notice they're more restrictive than the ConfigMap's by default.

<br>

<details><summary>Tip</summary>

```
kubectl create secret generic --help
```{{exec}}

```
kubectl exec secret-pod -- ls -l /etc/secret
```{{exec}}

</details>

<details><summary>Solution</summary>

```
kubectl create secret generic app-secret --from-literal=password=s3cr3t
```{{exec}}

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: secret-pod
spec:
  containers:
  - name: busybox
    image: busybox
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: secret-vol
      mountPath: /etc/secret
  volumes:
  - name: secret-vol
    secret:
      secretName: app-secret
EOF
```{{exec}}

```
kubectl exec secret-pod -- cat /etc/secret/password
kubectl exec secret-pod -- ls -l /etc/secret
```{{exec}}

</details>
