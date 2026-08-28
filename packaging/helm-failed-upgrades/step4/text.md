
`podinfo4` is healthy, at revision 2 (2 replicas). Uninstall it — but use the flag that keeps its release history instead of wiping it out entirely.

Check `helm list`: `podinfo4` is still right there, just with STATUS `uninstalled` — `helm list` shows every status by default. Find the flag that narrows it down to **only** uninstalled releases, and separately, the flag that shows **only** healthy ones (hiding `podinfo4` again). Confirm `helm history podinfo4` still works even though nothing is running.

Then bring it back — no `helm install` involved. Roll it back to revision 1. Confirm it's `deployed` again, running **1** replica (revision 1's value, not revision 2's), and that the release now has more history entries than before, not fewer.

<br>

<details><summary>Tip</summary>

```
helm uninstall --help | grep -A2 '\-\-keep-history'
helm list --help | grep -B1 -A1 '\-\-uninstalled\|\-\-deployed'
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
helm list --deployed
helm history podinfo4
```{{exec}}

Bare `helm list`: still there, `STATUS: uninstalled`. `--uninstalled` isolates just it; `--deployed` filters it back out. Either way, the release record — and its history — never left.

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
