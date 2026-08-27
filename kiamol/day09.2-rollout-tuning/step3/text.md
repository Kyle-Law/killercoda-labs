
`history-app` has been through 5 releases, and every one of them left a ReplicaSet behind — old ones scaled to 0, kept purely so you can roll back to them.

That retention is configurable, and the default (10) is more than most teams need. Configure `history-app` to retain only **2** old ReplicaSets, and confirm the extras are garbage-collected.

<br>

<details><summary>Tip</summary>

```
kubectl get rs -l app=history-app
kubectl explain deployment.spec.revisionHistoryLimit
```{{exec}}

The limit counts **old** ReplicaSets only — the currently-active one is always kept on top of that. Work out what the resulting total should be before you check.

</details>

<details><summary>Solution</summary>

```
kubectl patch deployment history-app --type merge -p '{"spec":{"revisionHistoryLimit":2}}'
```{{exec}}

```
kubectl get rs -l app=history-app
kubectl rollout history deployment/history-app
```{{exec}}

Three ReplicaSets remain: the active one, plus the 2 retained for rollback. The older revisions are gone from `rollout history` too — you can no longer `undo --to-revision` to them.

</details>
