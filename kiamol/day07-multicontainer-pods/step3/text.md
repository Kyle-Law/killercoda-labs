
`legacy-app` writes a timestamp to `/logs/app.log` every 5 seconds, but never writes to stdout — `kubectl logs legacy-app -c app` shows nothing, and there's no way to change that without touching the app itself.

Add a **sidecar** container named `logger` (image `busybox`) that mounts the same `logs` volume read-only and tails `app.log`, so its content becomes visible via `kubectl logs legacy-app -c logger` — without modifying the `app` container at all.

<br>

<details><summary>Tip</summary>

`containers` isn't a field you can patch on a live Pod — get its YAML, add the sidecar, delete the Pod, reapply.

```
kubectl get pod legacy-app -o yaml > /root/legacy-app.yaml
```{{exec}}

`tail -f <file>` is the core of it: it keeps running, echoing new lines to stdout as they're written. Both containers start at roughly the same time, though — `tail -f` on a file that doesn't exist yet just exits, so the sidecar's command needs to handle that.

</details>

<details><summary>Solution</summary>

```
kubectl delete pod legacy-app
```{{exec}}

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: legacy-app
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "while true; do date >> /logs/app.log; sleep 5; done"]
    volumeMounts:
    - name: logs
      mountPath: /logs
  - name: logger
    image: busybox
    command: ["sh", "-c", "while [ ! -f /logs/app.log ]; do sleep 1; done; tail -f /logs/app.log"]
    volumeMounts:
    - name: logs
      mountPath: /logs
      readOnly: true
  volumes:
  - name: logs
    emptyDir: {}
EOF
```{{exec}}

```
kubectl logs legacy-app -c logger --follow --tail=5
```{{exec}}

</details>
