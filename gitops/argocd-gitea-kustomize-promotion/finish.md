
<br>

### Recap

- **Two Applications, one `repoURL`, two `path`s.** That's the whole multi-environment Kustomize layout. Argo CD runs `kustomize build` per path, server-side — no values file, and no Kustomize CLI anywhere in the loop.
- **Promotion is a commit.** There is no artifact to move and nothing to copy out of staging: prod's overlay is edited to name the tag staging already names. The audit trail is `git log`, and it names one environment per commit.
- **Paths scope reconciliation.** A commit under `overlays/staging/` never made `solar-prod` go `OutOfSync`, despite both Applications watching the same branch of the same repository.
- **Overlay differences survive promotion.** Prod kept its two replicas through the tag change, because that setting lives in prod's overlay and was never part of what moved.
- **A base commit reaches every environment at once.** Same repo, same `git log`, no promotion — and with `automated` sync on both, it is a production deploy that never passed through staging.

### The asymmetry to remember

Editing an overlay is a scoped, reviewable change. Editing the base is a change to everything, and it looks exactly the same in the commit history. Pin `targetRevision`, split the repos, drop `automated` from prod, or guard `base/` in review — but pick one, because nothing in the tooling will point this out for you.

### WELL DONE!
