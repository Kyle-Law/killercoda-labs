
<br>

`gitops/argocd-ui-solar-system` sourced its Application from GitHub — a repo neither you nor Argo CD had any control over beyond reading it. This lab closes that gap: **Gitea**, a full self-hosted Git server, runs in the same cluster, reachable over its own NodePort, right alongside Argo CD's. You create the repo, you push the commits, Argo CD watches *your* Git server — not somebody else's.

Same app as before — `handafew/solar-system`, no database, dead simple — but this time you write its manifests into a repo that exists only because you made it exist, in this session, in this cluster.

Two NodePorts to keep straight throughout: Argo CD's UI on `30080`, Gitea's on `30300`. The app itself, once deployed, adds a third on `30090`.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
