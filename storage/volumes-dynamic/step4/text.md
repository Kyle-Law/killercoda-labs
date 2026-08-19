
Create a `ConfigMap` named `app-config` with a single key `app.properties` whose value is exactly `color=blue`.

Then create a Pod named `config-pod` (image `busybox`, long-running command) that mounts `app-config` as a volume at `/etc/config`. Confirm `/etc/config/app.properties` contains `color=blue`.

<br>

<details><summary>Tip</summary>

```
kubectl create configmap --help
```{{exec}}

```
kubectl explain pod.spec.volumes.configMap
```{{exec}}

</details>

<details><summary>Solution</summary>

```
kubectl create configmap app-config --from-literal=app.properties=color=blue
```{{exec}}

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: config-pod
spec:
  containers:
  - name: busybox
    image: busybox
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: config-vol
      mountPath: /etc/config
  volumes:
  - name: config-vol
    configMap:
      name: app-config
EOF
```{{exec}}

```
kubectl exec config-pod -- cat /etc/config/app.properties
```{{exec}}

</details>
