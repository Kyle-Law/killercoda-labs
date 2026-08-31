
`kustomize-guestbook` is synced — a plain Kustomize overlay (no Helm anywhere), sourced from `argocd-example-apps`. Log in to core mode.

The Application's committed `kustomization.yaml` sets `namePrefix: kustomize-` and lists a Deployment and a Service, both originally named `guestbook-ui`. Confirm the live resource names reflect that prefix, then confirm `argocd app manifests` is showing you a real `kustomize build` — not just the raw source files un-prefixed.

<br>

<details><summary>Tip</summary>

```
argocd login --core
kubectl -n default get deploy,svc
```{{exec}}

`argocd app manifests` renders and prints exactly what got applied — compare it against what a plain `kubectl kustomize` on the same directory would produce, if you had the repo checked out locally.

</details>

<details><summary>Solution</summary>

```
kubectl -n default get deploy,svc
```{{exec}}

`kustomize-guestbook-ui`, not `guestbook-ui` — the `namePrefix` from `kustomization.yaml` took effect.

```
argocd app manifests kustomize-guestbook
```{{exec}}

The rendered names, labels, and image all match what `kustomize build` on that directory would produce — Argo CD isn't inventing its own interpretation of the overlay, it's running the real tool and applying its real output.

</details>
