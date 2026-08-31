
<br>

Argo Rollouts is a separate project from Argo CD — its own CRDs (`Rollout`, `AnalysisTemplate`, `Experiment`), its own controller, its own `kubectl` plugin. It works with or without Argo CD; nothing here depends on any of the other `gitops/` labs. A `Rollout` is a drop-in replacement for a `Deployment` that adds exactly one thing: a `strategy`, controlling *how* a new version replaces the old one instead of just replacing it all at once.

Every image used here is `argoproj/rollouts-demo`, in three tags — `blue`, `yellow`, `red` — built by the Argo Rollouts project specifically so a rollout's progress is visually obvious. `kubectl-argo-rollouts` (the plugin) isn't installed by default here, so the first step installs it and the controller — not the skill being tested.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
