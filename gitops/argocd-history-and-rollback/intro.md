
<br>

`packaging/helm-failed-upgrades` covered `helm rollback` in depth: it doesn't rewind history, it copies an old revision forward as a brand new one — and once it's done, that new revision *is* the release's current state, permanently, until something else changes it.

`argocd app rollback` looks like the same idea and shares the append-only history model. It is not the same operation underneath, and the difference is the kind of thing that bites you in production at the worst possible moment: an Argo CD rollback is a **one-time sync to old content**, not a change to what the Application considers its desired state. Leave automated sync on, or even just run a plain `sync` afterward, and the rollback quietly undoes itself.

One Application throughout, `podinfo` — sourced directly as a Helm chart (no Git repo involved, just `stefanprodan.github.io/podinfo` as a chart repo), so each step can build history by changing a Helm parameter and syncing, without needing write access to a Git repo.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
