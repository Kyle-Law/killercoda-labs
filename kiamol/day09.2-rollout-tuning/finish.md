
<br>

### Recap

- `progressDeadlineSeconds` is what turns "this rollout is hanging" into a machine-readable failure: the `Progressing` condition flips to `False` with reason `ProgressDeadlineExceeded`, and `kubectl rollout status` exits non-zero instead of blocking. The default of 10 minutes is usually far too long for a pipeline.
- A percentage canary needs no special resource at all — two Deployments sharing one Service selector, and the split is just the ratio of Ready Pods. 1 of 5 is 20%; widening it is `kubectl scale` on both sides.
- `revisionHistoryLimit` caps retained **old** ReplicaSets (the active one is always kept on top). It's a direct trade: less clutter, but fewer revisions you can actually `undo --to-revision` back to.

None of these three live in `spec.template`, so changing any of them never triggers a rollout by itself — same as `replicas`.

### WELL DONE!

Rollout defaults are tuned for safety, not for your pipeline or your risk appetite. These are the knobs that make a Deployment's release behavior match how your team actually ships.
