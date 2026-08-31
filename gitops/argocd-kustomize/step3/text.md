
`kustomize-guestbook` is clean again — `kustomize-guestbook-ui` is live, from the committed `namePrefix: kustomize-`.

Override the prefix from the CLI: `--nameprefix test-`. Before running the sync, predict what happens to `kustomize-guestbook-ui` — does it get renamed to `test-guestbook-ui` in place, or something else? Sync, then check what's actually running, and what `argocd app get` says about the resources that used to exist.

<br>

<details><summary>Tip</summary>

```
argocd app set --help | grep -A1 'nameprefix\b'
```{{exec}}

A CLI-level `--nameprefix` doesn't merge with the committed `kustomization.yaml`'s own `namePrefix` — it **replaces** it entirely. And a name change was never something Kubernetes lets you apply in place to an existing object; a new name always means a new object.

</details>

<details><summary>Solution</summary>

```
argocd app set kustomize-guestbook --nameprefix test-
argocd app sync kustomize-guestbook
```{{exec}}

```
kubectl -n default get deploy,svc
argocd app get kustomize-guestbook
```{{exec}}

`test-guestbook-ui` now exists — but `kustomize-guestbook-ui` is *still there too*, marked `OutOfSync` with `ignored (requires pruning)`. Argo CD created new resources under the new name; it never renames anything, and the old ones just sit there orphaned, invisible to the new desired state, until something explicitly removes them.

```
argocd app sync kustomize-guestbook --prune
kubectl -n default get deploy,svc
```{{exec}}

Now `kustomize-guestbook-ui` is gone — `--prune` is what actually deletes resources that no longer appear in the desired state, and it's opt-in on every sync for exactly this reason.

</details>
