
<br>

Argo CD's entire value proposition is one sentence: the cluster should always match Git. This lab is about the gap between "should" and "does" — what Argo CD actually checks, on what trigger, and what it leaves alone unless you explicitly ask it not to.

One Application throughout, `guestbook` — the canonical Argo CD example app, a single Deployment and Service — evolving through four sync policies: unmanaged, manual, automated, and automated-with-self-heal.

This lab installs **Argo CD Core**: no UI, no API server, no Dex, no notifications-controller — just the application-controller, repo-server, redis, and applicationset-controller. Four Pods instead of eight. The `argocd` CLI still works exactly the same; in core mode it spawns a short-lived local API server per command instead of talking to a running one. `argocd` isn't installed by default here, so step 1 installs it — not the skill being tested.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
