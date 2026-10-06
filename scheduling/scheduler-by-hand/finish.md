
<br>

### Recap

**A scheduler is an API client that writes one field.** `kube-scheduler` watches for Pods with no node, chooses one, and POSTs a `Binding`. That is the whole interface, which is why sixteen lines of bash can do it, and why a Pod's `spec.nodeName` can be set by hand, by a controller, or by a different scheduler without anyone's permission.

**No `FailedScheduling` event and no `PodScheduled` condition means no scheduler has tried** — the symptom of a scheduler that is down, a `schedulerName` nobody runs, or one that has not got to it. A Pod a scheduler *has* refused says so, and says why, for every node.

**A Pod bound by hand has no `Scheduled` event** — that one is written by the scheduler, not the API. What events it does have — `Pulling`, `Pulled`, `Created`, `Started` — are the kubelet's. And `Binding` validates nothing about the node: bound to one that does not exist, the Pod sits `Pending` for about a minute and is then **deleted**, not failed, by the pod garbage collector.

**When the scheduler is skipped, the kubelet re-checks some of its rules and not others.** The four checked here:

| Rule you broke | Who objects | What you are left with |
|---|---|---|
| `NoSchedule` taint | nobody | a Pod that runs |
| `nodeSelector` | the kubelet — `Predicate NodeAffinity failed` | a `Failed` Pod, still in the API |
| `NoExecute` taint | the kubelet *and* the `taint-eviction-controller` | no Pod; two events |
| CPU request over capacity | the kubelet — `OutOfcpu` | a `Failed` Pod, still in the API |

`NoExecute` is the one taint effect enforced after scheduling, by two components, which is why it is the only one that also evicts Pods that were already there.

**`Failed` is terminal, and nothing is looking after the pile.** A Pod the kubelet rejects goes to phase `Failed` and is never rescheduled. A `ReplicaSet` counts only active Pods, so it makes a replacement; a scheduler that does not check fit places it on the same node; the kubelet rejects it. There is no back-off in that cycle, and no garbage collection of the corpses until there are 12500 of them.

### WELL DONE!

You now know what the scheduler's job is, which of its rules are *its* rules, and what a cluster does with a Pod that the scheduler never saw.

## Where to go next

- [`workloads/scheduling-constraints`](../../workloads/scheduling-constraints/) — the Pods the default scheduler *did* see and refused, and how to read why
- [`troubleshooting/control-plane`](../../troubleshooting/control-plane/) — the same no-events symptom, caused by a broken scheduler rather than a missing one
- [`scheduling/scheduler-profiles`](../scheduler-profiles/) — changing how the real scheduler decides, rather than replacing it *(planned)*

> See [`scheduling/README.md`](../README.md) for how this lab relates to the rest of the set.
