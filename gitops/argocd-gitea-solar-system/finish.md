
<br>

### Recap

- Gitea is a real, complete Git server — SQLite-backed here to keep it light, but the same HTTP-based clone/push/pull any other Git host supports. `INSTALL_LOCK=true` skips its first-run setup wizard; the admin account still has to be created explicitly, via `gitea admin user create` inside the Pod.
- Argo CD's `repo-server` runs inside the cluster, so it should reach Gitea the way anything else in-cluster reaches a Service — by DNS name (`gitea.gitea.svc.cluster.local`), not by NodePort. NodePort is for you, from outside; ClusterIP-via-DNS is for Argo CD, from inside. Both point at the same Gitea, over two different paths.
- A `git push` doesn't make Argo CD aware of anything by itself. Without a webhook, Argo CD only learns about a new commit on its own periodic poll (a few minutes, by default) — or immediately, if something explicitly asks it to check: a **Refresh**, or a **Sync** (which refreshes as part of what it does).
- `Sync Status` in the UI can be stale the moment after you've pushed — it's reporting the last time Argo CD actually looked, not a live subscription to your Git server.

### WELL DONE!

The whole loop, start to finish, never left infrastructure you controlled: your own Git server, your own commits, your own Argo CD watching them. Nothing about GitOps here required an external service at all — just Git, and something willing to keep checking it.
