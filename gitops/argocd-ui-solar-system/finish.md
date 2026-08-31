
<br>

### Recap

- Argo CD's full install adds the API server, UI, Dex, Redis, and notifications-controller on top of what Core already has — the only one that matters for this lab is the API server, since it's what serves the UI and what `argocd-server`'s Service exposes.
- A `ClusterIP` Service is invisible outside the cluster by design. `NodePort` is the plainest way to change that: same Service, a port opened on every node, reachable at `<any node IP>:<nodePort>` — no LoadBalancer, no Ingress controller required.
- The `Create Namespace` sync option matters the first time an Application targets a namespace that doesn't exist yet — without it, the very first sync fails outright, not silently.
- Clicking **Sync** in the UI is not a "keep what's running" or "promote this" button. It reapplies Git, full stop — a manual change made straight to the cluster gets overwritten the moment someone syncs, even if that change looks like an improvement.
- **Auto-Sync** plus **Self Heal**, both one checkbox each in the UI's Sync Policy panel, is what turns that overwrite from "the next time someone happens to click Sync" into "within a couple of seconds, automatically."

### WELL DONE!

Every mechanism here — NodePort, sync reverting drift, self-heal — is identical to what the CLI-driven labs elsewhere in `gitops/` already cover. The UI doesn't change what Argo CD does; it changes how many of Argo CD's own defaults you have to already know before you can see it.
