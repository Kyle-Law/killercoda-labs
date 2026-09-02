
<br>

There is no GPU in this cluster. You are going to schedule GPU workloads on it anyway — and everything you observe will be exactly how a real GPU cluster behaves.

That works because Kubernetes has no idea what a GPU is. Accelerators are **extended resources**: opaque integer counters attached to a node, which the scheduler treats as scarce. The NVIDIA device plugin's entire job is to count the GPUs it finds and advertise that number. Nothing downstream — scheduling, quota, preemption — knows the difference between a real GPU and one you declared yourself.

So you can learn the part that actually bites in production, which is not "how do I get CUDA working" but **how a cluster shares a resource nobody can overcommit and everybody wants.**

> The node's name is in `/root/nodename` — the steps use `$(cat /root/nodename)`.
