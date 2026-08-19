
A ServiceAccount named `node-viewer-sa` should be able to list Nodes — cluster-wide, since Nodes aren't namespaced. A `ClusterRole` named `node-viewer` already grants `list` on `nodes`, and it's bound to the ServiceAccount. It still doesn't work. Find out why, then fix it.

<br>

<details><summary>Tip</summary>

```
kubectl auth can-i list nodes --as=system:serviceaccount:default:node-viewer-sa
kubectl get rolebinding node-viewer-binding -o yaml
```{{exec}}

A `RoleBinding` can reference a `ClusterRole`, but the binding itself is still scoped to one namespace. Nodes aren't in any namespace at all.

</details>

<details><summary>Solution</summary>

Granting access to a cluster-scoped resource needs a **ClusterRoleBinding**, not a RoleBinding:

```
kubectl create clusterrolebinding node-viewer-binding --clusterrole=node-viewer --serviceaccount=default:node-viewer-sa
```{{exec}}

```
kubectl auth can-i list nodes --as=system:serviceaccount:default:node-viewer-sa
```{{exec}}

</details>
