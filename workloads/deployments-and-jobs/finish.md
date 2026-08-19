
<br>

### Recap

- `kubectl set image` triggers a rolling update — old and new Pods coexist briefly, replaced gradually rather than all at once.
- `kubectl rollout status` tells you whether a rollout actually finished; `kubectl rollout history` and `kubectl rollout undo` are how you recover from a bad one. Rolling back returns to the exact previous revision automatically — no need to remember what the old image tag was.
- A `CronJob`'s `.status.lastSuccessfulTime` is the fastest way to confirm it has actually fired successfully, rather than guessing from wall-clock time.

### WELL DONE!

Same mechanics apply whether you're pushing a new version or recovering from a bad one — a Deployment's revision history is the safety net either way.
