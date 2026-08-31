
`sync-waves` is freshly synced again. This time, break only the **last** wave — delete the `frontend` ReplicaSet (wave 2), leaving `backend` (wave 0) and both hook Jobs completely untouched.

Before syncing, predict: since `backend` doesn't need anything and the `maint-page-up` hook already ran successfully once, will this sync skip straight to recreating `frontend`, or does it start over from `PreSync`? Record the `upgrade-sql-schema...` Job count and `maint-page-up`'s Job UID first, then sync and check both again.

<br>

<details><summary>Tip</summary>

```
kubectl -n default delete replicaset frontend
```{{exec}}

A sync doesn't ask "what's different" and jump straight there — it re-runs the entire hook and wave sequence in order, every time, regardless of which wave actually needed a change.

</details>

<details><summary>Solution</summary>

```
kubectl -n default get job -o name | grep -c upgrade-sql-schema
kubectl -n default get job maint-page-up -o jsonpath='{.metadata.uid}'
```{{exec}}

```
kubectl -n default delete replicaset frontend
argocd app sync sync-waves
```{{exec}}

```
kubectl -n default get job -o name | grep -c upgrade-sql-schema
kubectl -n default get job maint-page-up -o jsonpath='{.metadata.uid}'
```{{exec}}

One more `upgrade-sql-schema...` Job than before, and `maint-page-up` has a new UID — both reran in full, even though `backend` (wave 0) was already exactly right and didn't need to change at all. Only `frontend` (wave 2) actually needed fixing, but every wave ahead of it ran again anyway.

</details>
