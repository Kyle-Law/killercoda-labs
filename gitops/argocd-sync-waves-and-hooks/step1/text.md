
The `sync-waves` Application already synced during setup — its manifest defines, in this order: a `PreSync` hook Job (`upgrade-sql-schema...`), a `backend` ReplicaSet+Service (no wave annotation — default wave `0`), a `Sync` hook Job (`maint-page-up`, wave `1`), a `frontend` ReplicaSet+Service (wave `2`), and another `Sync` hook Job (`maint-page-down`, wave `3`).

Log in to core mode. Before looking at anything, predict the order those five things actually came up in. Then confirm it using each resource's `creationTimestamp` — not `argocd app get`'s listing order, the *actual* timestamps.

<br>

<details><summary>Tip</summary>

```
argocd login --core
kubectl -n default get job,replicaset,svc --sort-by=.metadata.creationTimestamp -o custom-columns='KIND:.kind,NAME:.metadata.name,CREATED:.metadata.creationTimestamp'
```{{exec}}

A hook's phase (`PreSync`/`Sync`/`PostSync`) says *when relative to the sync* it runs. A `sync-wave` annotation — on a hook or an ordinary resource — says *how far into that phase*. `maint-page-up` is a `Sync`-phase hook carrying `sync-wave: "1"`, which is why it lands between wave 0 and wave 2, not before everything else the way the `PreSync` hook does.

</details>

<details><summary>Solution</summary>

```
kubectl -n default get job,replicaset,svc --sort-by=.metadata.creationTimestamp -o custom-columns='KIND:.kind,NAME:.metadata.name,CREATED:.metadata.creationTimestamp'
```{{exec}}

`upgrade-sql-schema...` first (PreSync, runs before the sync proper even starts), then `backend` (wave 0, the implicit default), then `maint-page-up` (wave 1), then `frontend` (wave 2), then `maint-page-down` (wave 3) — exactly the order the annotations describe, and each wave waited for the previous one to be Healthy, not just applied.

</details>
