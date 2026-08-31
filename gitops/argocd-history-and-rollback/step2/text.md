
`podinfo` has the same three-entry history as last step: ID 0 was `replicaCount=1`, ID 1 was `2`, ID 2 is the current `3`.

Roll back to ID 0. Confirm the live Deployment is back to 1 replica, then look at `argocd app history` again — how many entries are there now? Did rolling back to ID 0 make ID 0 the newest entry, or did something else happen?

<br>

<details><summary>Tip</summary>

```
argocd app rollback --help
```{{exec}}

Compare this against what `packaging/helm-failed-upgrades` taught about `helm rollback` — same underlying philosophy, one word for it: append-only.

</details>

<details><summary>Solution</summary>

```
argocd app rollback podinfo 0
```{{exec}}

```
kubectl -n default get deployment podinfo
argocd app history podinfo
```{{exec}}

1 replica, and a **new** entry, ID 3 — not a rewind back to 3 total entries, a 4th one on top. History only ever grows, exactly like `helm history` does.

</details>
