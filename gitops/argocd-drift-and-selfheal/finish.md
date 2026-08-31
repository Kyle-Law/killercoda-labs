
<br>

### Recap

- `Sync Status` and `Health Status` are independent axes. Sync asks "does live state match Git?" Health asks "is that live state actually working?" Right after a sync, it's completely normal to see `Synced` + `Progressing` — Argo CD applied the manifest, the Deployment just hasn't rolled out yet. And `OutOfSync` + `Healthy` is just as valid: something changed outside Git, but whatever's running right now is fine.
- With no automation (the default), drift sits as `OutOfSync` forever — Argo CD only notices, it never acts. `argocd app sync` is a manual, deliberate decision every time.
- `syncPolicy.automated` alone only reacts to **new commits in Git** — it polls the repo, not the cluster. Change something live with `kubectl` and it will sit at `OutOfSync` indefinitely, exactly like the manual case, despite "automated" being on.
- `selfHeal: true` is what makes Argo CD *also* watch live state and react to drift it didn't cause — not just Git. It's a modifier on `automated`, not a separate policy; `--self-heal` alone (Argo CD's own CLI shorthand can trip you up here) does nothing without `--sync-policy automated` alongside it.
- `selfHeal` doesn't stop at field-level drift — deleting a resource Argo CD manages is just another form of "live state disagrees with Git," and it gets recreated the same way a scaled-down Deployment gets scaled back up.

### WELL DONE!

Every fact above was checked against a live cluster, including one that overturned the first draft of this lab: `--self-heal` looked like a standalone flag and isn't — `argocd app set --self-heal` with no sync policy silently does nothing, because self-heal only fires within an automated sync.
