
`podinfo` has just been rolled back to ID 0 — 1 replica, live. Before touching anything, run `argocd app get podinfo`. What does `Sync Status` say? That should be surprising: nothing changed since the rollback, so why would it be `OutOfSync`?

Look at the Application's own spec — specifically `spec.source.helm.parameters` — and compare it to what's actually running. Once you see the mismatch, predict what happens if you run a plain `argocd app sync` right now. Then run it and check the replica count.

<br>

<details><summary>Tip</summary>

```
kubectl get application podinfo -n argocd -o jsonpath='{.spec.source.helm.parameters}'
```{{exec}}

`argocd app rollback` changes what's running. It does not touch `spec.source` — the Application's own record of what it's *supposed* to be running. Those are now two different answers to "what should replicaCount be?", and a sync always trusts the spec.

</details>

<details><summary>Solution</summary>

```
argocd app get podinfo
```{{exec}}

`Sync Status: OutOfSync` — against its own spec, not against anything you touched.

```
kubectl get application podinfo -n argocd -o jsonpath='{.spec.source.helm.parameters}'
```{{exec}}

`replicaCount: 3` — still the last value you explicitly set, before the rollback ever happened. The rollback never updated it.

```
argocd app sync podinfo
```{{exec}}

```
kubectl -n default get deployment podinfo
```{{exec}}

Back to 3 replicas. The rollback got completely undone by an ordinary sync — because as far as the spec was ever concerned, 3 was still correct.

</details>
