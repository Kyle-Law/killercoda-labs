
`podinfo-helm` is `Synced` and `Healthy` — sourced straight from the podinfo Helm chart repository, no Git repo anywhere in its definition. Log in to core mode.

First, check the obvious place: does `helm` itself know this exists? Then check the Deployment's own labels — one of them makes a claim about how it was deployed. Is that claim true? Reconcile the two answers using `argocd app manifests`, which shows you exactly what Argo CD rendered and applied.

<br>

<details><summary>Tip</summary>

```
argocd login --core
helm list -A
```{{exec}}

The label in question is `app.kubernetes.io/managed-by`. It comes from the chart's own templates — `helm template` writes it in regardless of what tool actually ran that command, or what happened to the output afterward.

</details>

<details><summary>Solution</summary>

```
helm list -A
helm status podinfo-helm
```{{exec}}

Nothing. No release, anywhere, in any namespace.

```
kubectl -n default get deployment podinfo-helm -o jsonpath='{.metadata.labels}'
```{{exec}}

`app.kubernetes.io/managed-by: Helm` — which reads like proof a release exists, and isn't. It's baked into the chart's templates; it fires no matter who runs `helm template`.

```
argocd app manifests podinfo-helm
```{{exec}}

This is the real reconciliation: a fully-rendered, correct Helm template output — Argo CD ran `helm template` under the hood exactly as advertised. It just never ran `helm install`, so there's no release object anywhere for `helm` itself to find.

</details>
