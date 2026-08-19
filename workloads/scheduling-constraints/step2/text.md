
A taint was just added to the only node in this cluster. A Pod named `taint-pod` (no toleration) is stuck `Pending` as a result. Fix `taint-pod` so it tolerates the taint and schedules — **without removing the taint itself**.

<br>

<details><summary>Tip</summary>

```
kubectl describe node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') | grep -i taint
kubectl describe pod taint-pod
```{{exec}}

`tolerations` isn't a field you can patch on a live Pod — get its YAML, add the toleration, delete, reapply.

</details>

<details><summary>Solution</summary>

```
kubectl get pod taint-pod -o yaml > /root/taint-pod.yaml
```{{exec}}

Edit `/root/taint-pod.yaml` and add, under `spec`:

```yaml
tolerations:
- key: dedicated
  operator: Equal
  value: special
  effect: NoSchedule
```

```
kubectl delete pod taint-pod
kubectl apply -f /root/taint-pod.yaml
```{{exec}}

</details>
