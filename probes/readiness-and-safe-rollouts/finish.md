
<br>

### Recap

- With **no readinessProbe**, a container is Ready the moment its process starts. `sleep 3600` passes. Every safety mechanism above it — `maxUnavailable`, `availableReplicas`, `kubectl rollout status` — then operates correctly on a meaningless signal, which is why a total outage can exit `0`.
- A **readinessProbe** is what makes `maxUnavailable` mean anything. The same bad release that caused a full outage in step 1 could only take one replica out of service in step 2, and the rollout stopped making progress instead of completing.
- A readiness probe alone is still not enough. By default a Pod counts towards a rollout the **instant** it first reports Ready — so a release that looks healthy for 25 seconds rolls all the way through and then collapses. **`minReadySeconds`** is the soak: stay continuously Ready this long, or you don't count.
- **`maxUnavailable: 0`** stops a serving Pod being retired on the promise of an unproven one. It needs `maxSurge >= 1` to have anywhere to put the new Pod.
- **`progressDeadlineSeconds`** is what turns "stuck" into a non-zero exit code and a `Progressing=False` / `ProgressDeadlineExceeded` condition. Without it a contained rollout is safe but silent, and `rollout status` just blocks — for 10 minutes, by default.
- `minReadySeconds`, `progressDeadlineSeconds` and `strategy` live on `spec`, not `spec.template` — so setting them doesn't trigger a rollout, and they stay in force for the deploy that comes next.

### WELL DONE!

The same class of bad release went from *"green pipeline, total outage"* to *"red pipeline, zero user impact"* — without a single change to the application, and without anyone watching a dashboard.

Related labs in this set: `probes/restart-remove-or-wait` for what each probe does on failure, `kiamol/day09-rollouts-rollbacks` for `maxSurge`/`maxUnavailable` and rollback mechanics, and `kiamol/day09.2-rollout-tuning` for `progressDeadlineSeconds` on its own.
