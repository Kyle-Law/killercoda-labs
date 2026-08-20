
Create a Pod named `configured-app` with:

- an **init container** `init-config` (image `busybox`) that writes `ready` into `/config/status.txt` on a shared `emptyDir` volume, then exits
- an app container `app` (image `busybox`, long-running command) that mounts the same volume **read-only** at `/config`

The app container shouldn't be able to start until the init container has completed — that's built into how Kubernetes schedules init containers, not something you configure separately. Confirm `app` can read `/config/status.txt` as soon as it's ready, proving the init container really did run first.

<br>

<details><summary>Tip</summary>

```
kubectl explain pod.spec.initContainers
```{{exec}}

</details>

<details><summary>Solution</summary>

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: configured-app
spec:
  initContainers:
  - name: init-config
    image: busybox
    command: ["sh", "-c", "echo ready > /config/status.txt"]
    volumeMounts:
    - name: config
      mountPath: /config
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: config
      mountPath: /config
      readOnly: true
  volumes:
  - name: config
    emptyDir: {}
EOF
```{{exec}}

```
kubectl get pod configured-app -o jsonpath='{.status.initContainerStatuses[0].state.terminated.reason}'
kubectl exec configured-app -c app -- cat /config/status.txt
```{{exec}}

</details>
