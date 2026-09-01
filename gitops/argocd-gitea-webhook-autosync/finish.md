
<br>

### Recap

- A Gitea webhook closes the gap the last lab ended on: instead of Argo CD finding a new commit on its own multi-minute poll, Gitea tells it the moment `main` moves. For the payload to actually match anything, Gitea's `ROOT_URL` has to describe the repo the same way the Application's `repoURL` does — both pointed at the in-cluster Service DNS name, not the NodePort address a browser uses.
- Gitea won't call an internal address at all by default — `security.ALLOWED_HOST_LIST` is what allows a webhook aimed at `argocd-server.argocd.svc.cluster.local` to go out. Without it, delivery fails silently from Argo CD's side; the only trace is in Gitea's own logs.
- `selfHeal` and the webhook solve two different halves of the same problem. Git-side changes need something to tell Argo CD they happened — that's the webhook. Cluster-side changes don't: Argo CD is already watching every resource it manages via the Kubernetes API, live, so drift introduced with `kubectl` gets reverted as fast as a watch event arrives — no webhook equivalent needed in that direction.
- `prune: true` is `selfHeal`'s mirror image for resources instead of fields: something no longer declared in Git gets deleted from the cluster, not just left behind and ignored.

### WELL DONE!

Push, and it's there. Delete the file, and it's gone. Change it by hand, and it's undone. Three different kinds of drift, one Application, and nothing in this lab ever ran `argocd app sync`.
