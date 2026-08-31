
Same starting point as step 2: `podinfo` at `replicaCount=3`, three history entries behind it. This time, roll back to ID 0 **and make it stick** — turn on automated sync afterward and confirm it *stays* at 1 replica instead of snapping back to 3.

<br>

<details><summary>Tip</summary>

A rollback only changes what's running. For it to survive a resync, the spec has to agree with it — set the same value there too, the normal way you'd change any Helm parameter.

</details>

<details><summary>Solution</summary>

```
argocd app rollback podinfo 0
```{{exec}}

```
argocd app set podinfo --helm-set replicaCount=1
```{{exec}}

```
kubectl get application podinfo -n argocd -o jsonpath='{.spec.source.helm.parameters}'
```{{exec}}

Now the spec itself says `1` — this isn't a leftover live state anymore, it's the actual desired state.

```
argocd app sync podinfo
argocd app set podinfo --sync-policy automated --self-heal
```{{exec}}

```
kubectl -n default get deployment podinfo
argocd app get podinfo
```{{exec}}

Still 1 replica, `Synced`, `Healthy` — even with automated sync and self-heal watching. There's nothing left for a resync to "correct" back to, because the rollback and the spec finally agree.

</details>
