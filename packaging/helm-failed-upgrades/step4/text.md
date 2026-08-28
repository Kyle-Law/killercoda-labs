
`podinfo4` is healthy, at revision 2 (2 replicas). Uninstall it — but use the flag that keeps its release history instead of wiping it out entirely.

Confirm `helm list` no longer shows `podinfo4`, but its history hasn't actually gone anywhere: find the flag that lists uninstalled releases too, and check `helm history podinfo4` still works.

Then bring it back — no `helm install` involved. Roll it back to revision 1. Confirm it's `deployed` again, running **1** replica (revision 1's value, not revision 2's), and that the release now has more history entries than before, not fewer.

<br>

<details><summary>Tip</summary>

```
helm uninstall --help | grep -A2 '\-\-keep-history'
helm list --help | grep -A2 '\-\-uninstalled'
```{{exec}}

`helm rollback` doesn't care whether the release is currently installed — it only needs a kept history to copy a revision from.

</details>

<details><summary>Solution</summary>

```
helm uninstall podinfo4 --keep-history
```{{exec}}

```
helm list
helm list --uninstalled
helm history podinfo4
```{{exec}}

Gone from the default list, still very much alive in history.

```
helm rollback podinfo4 1
```{{exec}}

```
helm list
helm history podinfo4
kubectl get deployment podinfo4
```{{exec}}

`deployed`, 1 replica, and a history that's grown by one more revision — the rollback that brought it back doesn't overwrite anything, same as every other rollback in this lab.

</details>
