
<br>

### Recap

- A parent Application is a Kubernetes object like any other — `kubectl apply`, not `argocd app create`, not the UI. Everything downstream of it followed from that one file.
- Helm values passed through `spec.source.helm.valuesObject` are a real nested object, not flat `--set` strings — a list of environments, each with its own `replicaCount` and `ui.color`, all Argo CD needed to render three independent, real Helm releases from one chart.
- Argo CD only acts on what actually changed. Editing one entry in a values list re-renders the whole chart, but the diff against live state is still per-child — siblings whose rendered output didn't move never see a sync operation at all.
- `resources-finalizer.argocd.argoproj.io` is what turns "delete the Application object" into "delete the Application object *and* everything it owns." Without it, pruning a child leaves its Deployment and Service behind, orphaned.
- Removing something from a values list and re-applying is pruning — no different in kind from a webhook-triggered prune off a Git repo, just triggered by an in-place edit instead of a push.

### WELL DONE!

One file, three real environments, each running the same public Helm chart with its own values — added, changed, and removed without ever touching the chart itself, and without a UI or a `sync` command in sight.
