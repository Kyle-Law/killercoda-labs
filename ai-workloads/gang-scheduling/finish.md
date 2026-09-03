
<br>

### Recap

- **The default scheduler places Pods, not jobs.** It has no notion of "all of these or none", so two 3-GPU jobs on 4 GPUs will each take 2 and wait forever. Every accelerator allocated, zero work done, and both Deployments reported healthy — no event, no warning, no timeout.
- **Kueue sits in front of the scheduler.** Jobs are submitted `suspend: true` with a queue-name label; Kueue unsuspends one only when its *entire* request fits the quota. The scheduler never sees a partially-admitted job.
- **`ResourceFlavor` / `ClusterQueue` / `LocalQueue`** — the hardware kind, the pool and its quota, and a namespace's entry point into that pool.
- **Nominal quota is Kueue's model of your capacity, not a fact about it.** Set it higher than the cluster really has and you hand the scheduler an impossible problem, recreating the exact mess Kueue exists to prevent.
- **It adds no capacity.** Both jobs still run sequentially and take the same total time. The difference is that they finish at all.

### WELL DONE!

You reproduced a silent, permanent deadlock and then made it structurally impossible — the reason every serious GPU platform puts a queue in front of the scheduler.
