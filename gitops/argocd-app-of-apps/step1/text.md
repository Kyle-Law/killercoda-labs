
`app-of-apps` is synced — its source is a Helm chart (`apps/` from `argocd-example-apps`) whose templates render nothing but `Application` manifests, one per entry in its `applications` values list. This one was trimmed down to two entries: `guestbook` and `kustomize-guestbook`.

Log in to core mode. List every Application that exists, not just `app-of-apps` itself. How many are there, and — this is the part that's easy to miss — did you have to sync any of them yourself?

<br>

<details><summary>Tip</summary>

```
argocd login --core
argocd app list
```{{exec}}

Each generated child carries its own `syncPolicy.automated` in the parent's template — look at the chart's `templates/applications.yaml` in the `argocd-example-apps` repo if you want to see it directly.

</details>

<details><summary>Solution</summary>

```
argocd app list
```{{exec}}

Three: `app-of-apps` itself, plus `example.guestbook` and `example.kustomize-guestbook` — and both children already show `Synced`/`Healthy`, without you running `argocd app sync` on either. The parent only had to create the child `Application` objects; each one's own automated sync policy took it from there.

```
kubectl -n guestbook get deploy,svc
kubectl -n kustomize-guestbook get deploy,svc
```{{exec}}

Each child even landed in its own namespace, named after itself — the chart's default when no explicit `destination.namespace` is given.

</details>
