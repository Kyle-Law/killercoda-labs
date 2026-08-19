
A Pod named `crash-pod` in the `default` namespace is stuck in `CrashLoopBackOff`. Find out why, then fix it so it reaches and **stays** in `STATUS Running`.

<br>

<details><summary>Tip</summary>

```
kubectl describe pod crash-pod
kubectl logs crash-pod --previous
```{{exec}}

`command` isn't a field you can patch on a live Pod — you'll need to get its YAML, fix it, delete the Pod, and reapply.

</details>

<details><summary>Solution</summary>

```
kubectl get pod crash-pod -o yaml > /root/crash-pod.yaml
```{{exec}}

Edit `/root/crash-pod.yaml` and change the container's `command` to something that keeps running, e.g.:

```yaml
command: ["sh", "-c", "sleep 3600"]
```

```
kubectl delete pod crash-pod
kubectl apply -f /root/crash-pod.yaml
```{{exec}}

</details>
