
<br>

Same relationship as `gitops/argocd-helm`, different tool underneath: Argo CD runs `kustomize build` internally and applies the result, the same way it applies a plain manifest directory or a rendered Helm chart. Kustomize has no "release" concept to begin with, so there's no equivalent to "no Helm release ever exists" here — but Argo CD's CLI-level Kustomize overrides (`--kustomize-image`, `--nameprefix`, `--kustomize-common-label`, and others) create their own sharp edges, two of which are worth knowing about before they surprise you in a real cluster.

One source throughout: `kustomize-guestbook` from `argocd-example-apps` — the same repo `packaging/` and every other `gitops/` lab in this set sources `guestbook`, `podinfo`, `sync-waves`, and `helm-guestbook` from.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
