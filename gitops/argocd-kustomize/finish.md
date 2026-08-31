
<br>

### Recap

- Argo CD runs `kustomize build` and applies the output directly — `argocd app manifests` shows exactly what that build produced, the same relationship Helm sources have to `helm template`.
- `--kustomize-image` and `--kustomize-replica` override an image tag or a replica count from the CLI, without ever touching `kustomization.yaml` — the Kustomize equivalent of `--helm-set`.
- `--nameprefix` (and `--namesuffix`) **replace** whatever `namePrefix` the committed `kustomization.yaml` already sets — they don't add to it, and changing it doesn't rename existing resources in place. It creates resources under the new name and leaves the old ones behind as orphaned, `OutOfSync`, and explicitly marked `ignored (requires pruning)` until a sync with `--prune` removes them.
- `--kustomize-common-label` can break a sync outright: Kustomize's label transformer applies common labels to `spec.selector.matchLabels` by default, and that field is immutable on an existing Deployment — the sync fails with `field is immutable`, not a warning. `--kustomize-label-without-selector` is the fix: apply the label to metadata without touching selectors at all.

### WELL DONE!

Two different "looks safe, isn't" edges, same root cause both times: a Kustomize override that reaches further than the one field you meant to change.
