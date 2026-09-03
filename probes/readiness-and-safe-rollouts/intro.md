
<br>

`maxUnavailable` promises a rolling update will never take more than *N* replicas out of service at once. `kubectl rollout status` promises to tell you whether a deploy worked. Both promises are built on one thing: the **readiness probe**.

Take the readiness probe away and Kubernetes has no way to tell a serving Pod from a Pod whose process merely started. `maxUnavailable` still counts, but it's counting the wrong thing. `rollout status` still reports, but it reports success. The result is a deploy that exits `0`, shows `4/4` replicas ready, and serves not one single request — which is the first thing you'll do here, deliberately.

Then you'll build the fix in layers, and find out that a readiness probe alone still isn't enough:

- **readinessProbe** — makes "available" mean "actually serving"
- **minReadySeconds** — makes it mean "serving *and still serving* a moment later"
- **maxUnavailable: 0** — never give up a serving replica before its replacement earns the title
- **progressDeadlineSeconds** — turn a stuck rollout into a non-zero exit code your pipeline can fail on

`gitops/argocd-drift-and-selfheal` and `kiamol/day09-rollouts-rollbacks` cover rollout mechanics from the Deployment's side; `kiamol/day09.2-rollout-tuning` covers `progressDeadlineSeconds` on its own. This lab is about the probe underneath all of them.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
