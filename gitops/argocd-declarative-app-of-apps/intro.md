
<br>

`gitops/argocd-app-of-apps` covers the mechanics of one Application managing many — cascading deletion, ApplicationSet's list and git-directory generators. `gitops/argocd-helm` covers what changes when Argo CD sources a Helm chart directly. This lab assumes both and puts them together: a parent Application, written and `kubectl apply`'d by hand rather than clicked into existence, whose children aren't stub placeholders but real deployments of `podinfo` — the same public Helm chart from `gitops/argocd-helm` — one per environment, each with its own `replicaCount` and `ui.color`.

Nothing here is created through the UI, and nothing runs `argocd app create`. The parent is a Kubernetes object like any other; so is every child it generates. This installs Argo CD **Core** — no UI, no API server, no Dex — the same as `argocd-app-of-apps` and `argocd-drift-and-selfheal`; the `argocd` CLI works the same way, spawning a short-lived local API server per command.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
