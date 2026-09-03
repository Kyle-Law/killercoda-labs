
<br>

Distributed training is **all-or-nothing**. A job that needs 3 workers does no work at all with 2 of them scheduled — the workers rendezvous at startup and block until every peer arrives.

The default Kubernetes scheduler has no concept of this. It places Pods **one at a time**, taking whatever it can get. Two 3-GPU jobs on a 4-GPU node will each grab 2 GPUs and wait forever: every accelerator allocated, zero work produced, and both Deployments reported perfectly healthy.

This scenario reproduces that deadlock, then fixes it with [Kueue](https://kueue.sigs.k8s.io/) — a queueing layer that holds a job until its **entire** resource requirement can be satisfied at once, and only then lets it start.

> The node has been given 4 fake GPUs via an extended resource, so no hardware is involved. Its name is in `/root/nodename`.
