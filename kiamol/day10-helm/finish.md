
<br>

### Recap

- A chart repo is just an index of chart archives — pinning `--version` explicitly is the only way to know exactly what you're installing, since "latest" changes underneath you over time.
- `helm upgrade --set` changes values without touching the chart version; `helm get values` shows what you've overridden, distinct from the chart's own defaults. Overrides don't accumulate across upgrades on their own — each `--set` starts from the chart defaults again unless you add `--reuse-values`.
- `helm rollback` is the release-level version of `kubectl rollout undo`: it doesn't rewind history, it creates a **new** revision that copies an old one — `helm history` always grows, never shrinks.
- A chart is just files — `helm create` scaffolds one locally, and `helm install <name> <path>` installs straight from a directory. A repo is where charts get published for others, not a requirement for using one yourself.

### WELL DONE!

Everything here maps directly onto what you already know from `kubectl rollout` — Helm just adds a packaging and versioning layer on top of the same underlying Kubernetes objects.
