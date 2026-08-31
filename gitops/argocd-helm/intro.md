
<br>

`packaging/` spent two labs deep in the `helm` CLI. This one is about what changes when Argo CD is the thing installing a Helm chart instead of you.

The short version: Argo CD runs `helm template` internally, gets back a pile of plain Kubernetes manifests, and applies those the same way it applies anything else — a Kustomize build, a raw YAML directory, whatever. There is no `helm install`, no release Secret, nothing `helm list` will ever show you. If that sounds like it should change how you think about values overrides, hook flags, and what `--values` can and can't point at, it does.

Two sources across this lab: `podinfo`, pulled straight from its Helm chart repository (no Git involved at all, same chart used throughout `packaging/`), and `helm-guestbook` from `argocd-example-apps` — a chart committed to Git alongside more than one values file.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
