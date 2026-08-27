
<br>

Three Deployment fields that control *how* a release behaves, rather than what it ships — none of them part of `spec.template`, so setting any of them never triggers a rollout of its own:

- `progressDeadlineSeconds` — how long a stalled rollout waits before it's reported as failed
- replica ratio across two Deployments — a percentage canary, using nothing but a shared Service selector
- `revisionHistoryLimit` — how many old ReplicaSets are retained, and therefore how far back you can actually roll back

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
