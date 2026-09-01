
<br>

`gitops/argocd-gitea-solar-system` ended on a deliberate anticlimax: you pushed a real change to your own Gitea, and Argo CD had no idea until something explicitly told it to look — a manual `--refresh`. This lab removes that gap three different ways, all running together on one Application:

- A **webhook** — Gitea tells Argo CD the moment something changes, instead of Argo CD finding out on its own multi-minute poll.
- **Self-heal** — anything that changes the live cluster *without* going through Git gets reverted, not just flagged.
- **Auto-prune** — anything removed from Git gets removed from the cluster too, not just left behind.

Argo CD and Gitea are installed the same way as before — full install, both on NodePort, Gitea on SQLite. `gitops/argocd-drift-and-selfheal` covers the unmanaged → manual → automated → self-heal progression in much more depth, one policy at a time, if you want the slower version of that particular piece; this lab assumes you'd rather see all three working together against a real webhook.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
