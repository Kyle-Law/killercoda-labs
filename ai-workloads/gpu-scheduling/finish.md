
<br>

### Recap

You scheduled GPU workloads all the way through preemption and deadlock, on a cluster with no GPU — because **accelerators are just extended resources**, and every layer above the device plugin treats them identically.

- **Advertising is the device plugin's whole job.** `nvidia.com/gpu` is an opaque integer on the node's status. Nothing in the scheduler, quota system or preemption logic knows what it represents.
- **Accelerators break the rules CPU taught you.** Integers only, no overcommit, requests always equal limits. There's no bin-packing slack to reclaim, which is why GPU utilisation is a permanent operational problem rather than a tuning exercise.
- **Quota and the scheduler fail at different times.** Over quota, `kubectl` errors and no Pod is created. Over capacity, the Pod exists and waits. Same shortage, opposite symptom — and debugging the wrong layer wastes a lot of time.
- **Preemption is what makes sharing economically viable.** Researchers can saturate idle accelerators because production can reclaim them in seconds.
- **The default scheduler has no concept of all-or-nothing.** Two half-scheduled training jobs will hold every GPU forever and produce nothing, and Kubernetes will report both Deployments as healthy. Gang scheduling — Kueue, Volcano — exists precisely because that failure is silent and easy to cause.

### WELL DONE!

The hard part of GPU infrastructure was never CUDA. It's arbitrating a resource nobody can overcommit and everybody wants — and you've now done all of it.
