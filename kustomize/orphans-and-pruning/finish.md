
<br>

### Recap

- **`kubectl apply` has no concept of absence.** Remove a resource from a kustomization, re-apply, and the object stays — reported as a success, because `apply` reconciles what you gave it and says nothing about what you didn't.
- **Config-first tools cannot see orphans.** `kubectl diff -k` returned no differences and exit 0 while an unmanaged ConfigMap sat in the namespace. So do `kustomize build`, `--dry-run`, and reading the repo: all of them start from your configuration, and the orphan's defining property is that it isn't in it.
- **Finding orphans means starting from the cluster and subtracting** — which is why labelling everything you own is the practical answer. "Mine" becomes a query instead of an inference.
- **`--prune` enforces that claim destructively.** It deletes everything matching the selector that wasn't in this apply, including resources it has never seen before and that you never wrote.
- **The selector is the blast radius.** An unrelated ConfigMap created seconds earlier by another team was deleted because it wore the same label. Scope selectors to a single kustomization and a single namespace, and list what a selector matches before trusting it.

### Why GitOps controllers do this differently

Argo CD and Flux track ownership per application with their own metadata, rather than relying on a label you happen to pass on the command line. Pruning is then an explicit, per-application setting — which is the same idea as this lab, with the blast radius defined by the tool instead of by an argument you can get wrong.

### WELL DONE!
