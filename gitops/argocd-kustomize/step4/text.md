
`kustomize-guestbook-ui` is clean and running. Add a common label to every resource in this Application — `environment=production` — using the Kustomize common-label override, and sync.

This one doesn't go smoothly. Read the error carefully before deciding what to do about it.

<br>

<details><summary>Tip</summary>

```
argocd app set --help | grep -B1 -A2 'kustomize-common-label\|kustomize-label-without-selector'
```{{exec}}

Kustomize's label transformer applies common labels everywhere by default — including `spec.selector.matchLabels` on a Deployment. That field is set once, at creation, and Kubernetes refuses to let anything change it afterward.

</details>

<details><summary>Solution</summary>

```
argocd app set kustomize-guestbook --kustomize-common-label environment=production
argocd app sync kustomize-guestbook
```{{exec}}

`field is immutable` — the sync fails outright, not a warning, because the label transformer tried to rewrite `spec.selector.matchLabels` on a Deployment that already exists with a different selector.

```
argocd app set kustomize-guestbook --kustomize-label-without-selector
argocd app sync kustomize-guestbook
```{{exec}}

```
kubectl -n default get deployment kustomize-guestbook-ui -o jsonpath='{.metadata.labels}'
kubectl -n default get deployment kustomize-guestbook-ui -o jsonpath='{.spec.selector.matchLabels}'
```{{exec}}

`environment: production` is on the metadata; `spec.selector.matchLabels` never changed. Same label, applied everywhere it's safe to apply it and nowhere it isn't.

</details>
