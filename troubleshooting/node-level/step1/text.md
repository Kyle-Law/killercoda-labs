
A Deployment named `stuck-app` was created, but its Pods are stuck `Pending` — even though `kubectl get nodes` shows the node as `STATUS Ready`. Find out why, then fix it.

<br>

<details><summary>Tip</summary>

```
kubectl get nodes
kubectl describe node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') | grep -i schedul
```{{exec}}

`Ready` and `schedulable` aren't the same thing.

</details>

<details><summary>Solution</summary>

```
kubectl uncordon $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
```{{exec}}

```
kubectl get pods -l app=stuck-app
```{{exec}}

</details>
