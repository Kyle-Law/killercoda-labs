
<br>

[`workloads/scheduling-constraints`](../../workloads/scheduling-constraints/) reads one `FailedScheduling` event per Pod, each with one cause. That is the easy case. This lab is what the scheduler does when there are many nodes, each failing for its own reasons, and what it does when more than one node passes.

A scheduling decision has two halves. **Filter** removes the nodes the Pod cannot run on, and says why, once per node. **Score** ranks what is left, with about eight plugins casting weighted votes — most of them about rules the Pod's author never wrote. Both halves have a way of not showing you what you assumed, and you will meet each.

> There are twelve **fake nodes** (`kubectl get nodes -l type=kwok`) next to the real one, broken in different ways, and a Pod called `job` that fits none of them. They are real `Node` objects that the real scheduler places Pods on, and Pods bound to them report `Running` with nothing underneath.

Helpers are installed, because most of this lab is reading what the scheduler says:

- `why`{{exec}} — what the last check wanted
- `scores <pod> [node]` — what every plugin scored every node, for one Pod, from the scheduler's own log (step 2 turns that log on)
- `configz` — the configuration the scheduler is **running**, defaults applied: one line of JSON, so `grep -o` works; `configz -p` pretty-prints
- `restart-scheduler` — restarts the scheduler as a new Pod and waits for it
- `reset-nodes [N]` — puts the fake nodes back to a clean state: `N` of them (default 12), nothing on them, `kwok-node-5` labelled `tier=gold`

The scheduler is already reading a config file, `/etc/kubernetes/scheduler-config.yaml`, as it does at the end of the `scheduler-profiles` lab. Its manifest as this lab leaves it is in `/root/kube-scheduler.yaml.start`; if a step goes wrong enough that it will not come back, `cp` that over `/etc/kubernetes/manifests/kube-scheduler.yaml`.

<br>

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.

Each step is checked with the **CHECK** button. When a check does not pass, run `why`{{exec}} in the terminal — every check in this lab writes down which condition it was not happy with, rather than leaving you to guess.
