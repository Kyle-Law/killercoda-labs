
`podinfo-helm` is back to chart defaults. Bump `replicaCount` to `2`, and separately set `podAnnotations.build` to the bare number `42` with `--helm-set`. Every `HelmParameter` Argo CD stores is a plain string no matter which flag set it (`value: "42"` either way) — so where does the `--set` vs `--set-string` distinction actually live? Look at the *rest* of that parameter's fields in `kubectl get application -o yaml`, not just `value`.

Redo it with `--helm-set-string` instead and compare.

<br>

<details><summary>Tip</summary>

```
argocd app set --help | grep -A2 'helm-set\b\|helm-set-string'
```{{exec}}

`kubectl explain application.spec.source.helm.parameters` — there's a third field on each parameter besides `name` and `value`.

</details>

<details><summary>Solution</summary>

```
argocd app set podinfo-helm --helm-set replicaCount=2 --helm-set podAnnotations.build=42
argocd app sync podinfo-helm
```{{exec}}

```
kubectl get application podinfo-helm -n argocd -o yaml | grep -A2 'name: podAnnotations.build'
```{{exec}}

Just `name` and `value` — no third field. `value` is `"42"` either way; a plain string is all this field ever stores.

```
argocd app set podinfo-helm --helm-set-string podAnnotations.build=42
argocd app sync podinfo-helm
kubectl get application podinfo-helm -n argocd -o yaml | grep -A2 'name: podAnnotations.build'
```{{exec}}

Now there's a `forceString: true` sitting alongside it. That's the entire distinction — not a different stored value, a separate flag telling `helm template` to treat this one as a string no matter what it looks like, exactly like `--set-string` does for plain Helm.

</details>
