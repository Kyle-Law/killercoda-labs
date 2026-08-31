
Two Applications this time. `helm-guestbook` is sourced from Git (`argoproj/argocd-example-apps`, path `helm-guestbook`) — and that path has more than one values file committed alongside the chart: `values.yaml` (the default, currently active) and `values-production.yaml`.

Switch `helm-guestbook` to `values-production.yaml` using `--values` (the file-reference flag this time, not `--values-literal-file`) and confirm something actually changed on the live Service. Then try the exact same `--values` flag against `podinfo-helm` instead, pointed at any filename you like. Read the error.

<br>

<details><summary>Tip</summary>

```
kubectl -n default get svc helm-guestbook -o jsonpath='{.spec.type}'
```{{exec}}

`--values` only works when the file is real and reachable from wherever the source actually is. A Git-sourced chart has a whole repo to look in; a bare chart-repository source has nothing but the chart itself.

</details>

<details><summary>Solution</summary>

```
argocd app set helm-guestbook --values values-production.yaml
argocd app sync helm-guestbook
kubectl -n default get svc helm-guestbook -o jsonpath='{.spec.type}'
```{{exec}}

`LoadBalancer` — `values-production.yaml` only overrides `service.type`, and it took effect, read straight out of the Git repo alongside the chart. (Don't expect `Health Status` to settle to `Healthy` after this — a `LoadBalancer` Service never gets an external IP on a cluster like this one, so Argo CD's own health check for it sits at `Progressing` forever. That's an artifact of the environment, not something broken.)

```
argocd app set podinfo-helm --values somefile.yaml
```{{exec}}

Rejected immediately, before touching the cluster: `no such file or directory`. `podinfo-helm`'s source is just the packaged chart from a chart repository — there's no repo checkout for `somefile.yaml` to exist in, so there's nothing `--values` could ever point at here. `--values-literal-file` from last step sidesteps this entirely, because it never needed the file to live in the source in the first place.

</details>
