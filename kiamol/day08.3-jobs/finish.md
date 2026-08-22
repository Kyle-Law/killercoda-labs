
<br>

### Recap

- With `restartPolicy: Never`, a failed attempt is a brand-new Pod, not a restarted container — failed Pods pile up as visible evidence, up to `backoffLimit`. A Job's Pod template can't be edited in place, same as a bare Pod's.
- `completions` + `parallelism` turn a Job into a bounded batch runner: a fixed amount of total work, done in waves no wider than the parallelism limit.
- `activeDeadlineSeconds` is a different failure mode from `backoffLimit` entirely — wall-clock time across the whole Job, not a count of failed attempts. Watch for `reason: DeadlineExceeded` to tell them apart.
- `suspend` is mutable on a live CronJob — pausing it doesn't need a delete. `kubectl create job --from=cronjob/<name>` is the standard way to run an ad-hoc extra execution without touching the schedule at all.

### WELL DONE!

A Job isn't just "a Pod that runs once" — `backoffLimit`, `completions`/`parallelism`, and `activeDeadlineSeconds` are three independent knobs for controlling exactly how failure, scale, and time are handled, and CronJob just adds a schedule on top of all of it.
