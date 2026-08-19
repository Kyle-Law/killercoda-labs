
A Pod named `selector-pod` is stuck `Pending`. It has a `nodeSelector` requiring `disktype: ssd`. Find out why it won't schedule, then fix it — either by labeling the node correctly, or by adjusting the Pod, whichever you prefer.

<br>

<details><summary>Tip</summary>

```
kubectl get pod selector-pod -o yaml | grep -A2 nodeSelector
kubectl get nodes --show-labels
kubectl describe pod selector-pod
```{{exec}}

Check the `Events` section for `FailedScheduling`.

</details>

<details><summary>Solution</summary>

```
kubectl label node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') disktype=ssd
```{{exec}}

```
kubectl get pod selector-pod
```{{exec}}

</details>
