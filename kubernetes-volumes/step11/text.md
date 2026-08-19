
Without deleting or restarting `config-pod`, update `app-config`'s `app.properties` value to `color=red`.

The kubelet syncs mounted ConfigMap volumes on a delay (up to roughly a minute) — wait for it, then confirm `/etc/config/app.properties` inside the **already-running** `config-pod` now shows `color=red`, without the Pod ever restarting.

<br>

<details><summary>Tip</summary>

```
kubectl create configmap --help
```{{exec}}

`--dry-run=client -o yaml | kubectl replace -f -` is one way to overwrite an existing ConfigMap's data from the command line. `kubectl edit configmap app-config` works too.

</details>

<details><summary>Solution</summary>

```
kubectl create configmap app-config --from-literal=app.properties=color=red --dry-run=client -o yaml | kubectl replace -f -
```{{exec}}

Wait about a minute for the kubelet to sync the change to the mounted volume, then check again:

```
kubectl exec config-pod -- cat /etc/config/app.properties
```{{exec}}

</details>
