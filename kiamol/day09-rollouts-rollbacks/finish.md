
<br>

### Recap

- `kubectl rollout undo --to-revision=N` recovers any retained revision, not just the immediately previous one — `rollout history --revision=N` is how you confirm which one actually has what you need before committing.
- `Recreate` guarantees zero overlap between old and new Pods, at the cost of downtime. `RollingUpdate` with `maxUnavailable: 0` guarantees full capacity throughout, at the cost of temporarily exceeding the replica count. Neither is "better" — they trade off different constraints.
- `kubectl rollout pause` / `resume` lets you stage multiple template changes and ship them as a single revision — and a single rollback point — instead of one revision per change.
- Blue/green isn't a Deployment feature at all — it's two independent Deployments and a Service whose `selector` you flip. The release is instant and instantly reversible, precisely because the old version never stops running.

### WELL DONE!

A rolling update is the default, but it's one release strategy among several — knowing when to reach for `Recreate`, a paused batch, or a full blue/green split is what separates "I can update a Deployment" from "I can plan a release."
