
A ServiceAccount named `viewer-sa` in the `default` namespace needs to be able to list Pods. A Role named `pod-reader` already grants exactly that. Find out why `viewer-sa` still can't list Pods, then fix it.

<br>

<details><summary>Tip</summary>

```
kubectl auth can-i list pods --as=system:serviceaccount:default:viewer-sa
kubectl get role pod-reader -o yaml
```{{exec}}

A Role only takes effect once something binds it to an identity.

</details>

<details><summary>Solution</summary>

```
kubectl create rolebinding viewer-sa-binding --role=pod-reader --serviceaccount=default:viewer-sa
```{{exec}}

```
kubectl auth can-i list pods --as=system:serviceaccount:default:viewer-sa
```{{exec}}

</details>
