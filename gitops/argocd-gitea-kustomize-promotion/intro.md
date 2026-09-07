
<br>

With Helm, an environment is a values file and promotion is a flag. With Kustomize there are no values — there is a **base**, and an **overlay** per environment, and promotion is a commit that edits one overlay.

That makes the whole thing legible: the diff between staging and prod is a diff between two directories, and "what is in prod" is answerable by reading a file rather than by asking a cluster.

It also creates a hazard that values files don't have. Every overlay inherits from the same base, so a change made *there* reaches every environment at once — with no per-environment review, no ordering, and nothing to promote. The property that makes overlays convenient is the same one that makes an accidental base edit a production change.

You'll build the loop end to end: a repo in your own Gitea, two Argo CD Applications reading two paths out of it, a promotion through staging into prod, and then a one-line base edit that lands in both simultaneously.

> Argo CD and Gitea are installed for you in the first step. Both are on NodePort, and both auto-sync from the start.
