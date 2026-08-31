
<br>

A plain `kubectl apply -f` applies everything in a manifest set more or less at once, in whatever order the API server happens to process them. That's fine until it isn't — a schema migration that needs to run before the app starts, a frontend that shouldn't come up before its backend does, a maintenance page that needs to go up before anything changes and come down only after.

Argo CD's answer is two mechanisms that look similar and aren't: **sync waves** (`argocd.argoproj.io/sync-wave`, an integer — lower waves sync first, and a wave doesn't start until every resource in the previous wave is Healthy) and **hooks** (`argocd.argoproj.io/hook: PreSync|Sync|PostSync`, one-shot Jobs that run at specific points in the sync lifecycle). This lab uses the two examples straight from `argoproj/argocd-example-apps` — the same repo `packaging/` and the other `gitops/` labs already source `guestbook` and `podinfo` from — because they're the canonical, maintained demonstration of exactly this.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
