
A Pod named `oom-pod` in the `default` namespace keeps restarting. Find out why using its container's *last terminated* state, then fix the Pod so it stops being killed.

<br>

<details><summary>Tip</summary>

```
kubectl describe pod oom-pod
```{{exec}}

Look at `Last State` → `Reason` in the container status.

</details>

<details><summary>Solution</summary>

The container is asking for more memory than its limit allows. Resource limits, like `command`, aren't live-patchable on a running Pod:

```
kubectl get pod oom-pod -o yaml > /root/oom-pod.yaml
```{{exec}}

Edit `/root/oom-pod.yaml` and raise `resources.limits.memory` well above the workload's needs, e.g.:

```yaml
resources:
  requests:
    memory: "20Mi"
  limits:
    memory: "300Mi"
```

```
kubectl delete pod oom-pod
kubectl apply -f /root/oom-pod.yaml
```{{exec}}

</details>
