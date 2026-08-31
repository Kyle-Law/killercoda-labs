
`podinfo` is synced at `replicaCount=1` — sourced straight from the podinfo Helm chart repo, no Git repo in the picture at all. Log in to core mode, then build up some history: change `replicaCount` to `2` and sync, then change it to `3` and sync. You should end up with three history entries.

Run `argocd app history podinfo`. Notice what's *missing* — the table tells you when each sync happened and what chart revision it used, but nothing about what `replicaCount` was at each point. Find another way to read that back, per entry, from the Application object itself.

<br>

<details><summary>Tip</summary>

```
argocd login --core
argocd app set --help | grep -A2 'helm-set '
```{{exec}}

`argocd app history` is deliberately thin — it's a changelog of *when*, not *what*. The full picture, including per-sync parameter overrides, lives in the Application's own `.status.history` field.

</details>

<details><summary>Solution</summary>

```
argocd login --core
```{{exec}}

```
argocd app set podinfo --helm-set replicaCount=2
argocd app sync podinfo
```{{exec}}

```
argocd app set podinfo --helm-set replicaCount=3
argocd app sync podinfo
```{{exec}}

```
argocd app history podinfo
```{{exec}}

Three entries, but no `replicaCount` column anywhere.

```
kubectl get application podinfo -n argocd -o jsonpath='{range .status.history[*]}{.id}{": replicaCount="}{.source.helm.parameters[0].value}{"\n"}{end}'
```{{exec}}

That's the only place the per-sync values actually live.

</details>
