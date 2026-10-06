# Schedule a Pod by Hand

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **Topic** | What a scheduler *is*: a client that writes one field, and what checks it after |
| **CKA relevance** | Workloads & Scheduling: `nodeName`, manual scheduling, and why a Pod is `Pending` |
| **Proposed backend** | `kubernetes-kubeadm-2nodes`. Steps 4–5 need a real kubelet on a node that has a choice |
| **Feasibility** | Ready. No new components. Three behavioural claims to verify (below) |

## What it teaches

Every other lab treats `kube-scheduler` as the thing that places Pods. This one shows that it is just
*a* thing that places Pods. It's an ordinary API client: it watches unbound Pods that name it, picks a
node, and POSTs a `Binding`. Anything else that writes the same field schedules the Pod too, and none
of the scheduler's rules apply to it.

## The finding at its heart

**The scheduler is not a gate.** Taints, affinity and resource fit are enforced only by the client
that chooses to enforce them. Bypass it, and the only remaining check is the kubelet's admission. That
re-checks resources and node affinity but, by its own source comment, *"is only interested in the
NoExecute taint"*. A `NoSchedule` taint simply isn't there.

What the kubelet *does* reject, it rejects for good. A Pod refused at admission goes `Failed`, not
back to `Pending`. Nothing reschedules it. If it belongs to a ReplicaSet, the ReplicaSet creates a
replacement, your scheduler binds it to the same node, and the loop fills the namespace with `Failed`
Pods.

## Step outline

1. **Pending, with nothing to say.** Two Pods are `Pending` with `Events: <none>`. One names a
   `schedulerName` nobody runs. The other carries a `schedulingGates` entry, and `kubectl get` shows
   it as `SchedulingGated`. Compare both with a Pod that has an impossible `nodeSelector`, which does
   get a `FailedScheduling` event. The rule to leave with: **no `FailedScheduling` event means no
   scheduler has tried**. That's the same symptom as a dead scheduler in
   [`troubleshooting/control-plane`](../../troubleshooting/control-plane/) step 1.
2. **Be the scheduler once.** Bind the first Pod with a `Binding` POSTed to the `pods/binding`
   subresource (`kubectl create --raw`). It runs. Look for the `Scheduled` event you'd normally see.
   It isn't there, because that event is written by the scheduler, not by the API. Then bind a second
   Pod to a node that does not exist. The API accepts it.
3. **Be the scheduler in a loop.** About thirty lines of bash: list Pods with
   `--field-selector spec.schedulerName=by-hand,spec.nodeName=`, pick the node with the fewest Pods,
   and bind. It's a working scheduler with one scoring rule and no filters. Gate: a three-replica
   Deployment naming `by-hand` is fully `Running`.
4. **The rules you skipped.** Taint `node01` with `NoSchedule` and scale up: the bash scheduler binds
   there and the Pods run. Change the effect to `NoExecute`: the kubelet refuses the Pod at admission.
   Raise a container's CPU request past `node01`'s allocatable: `OutOfcpu`, phase `Failed`. For each
   case, write down which component said no, in `/root/answers`.
5. **Failed is terminal.** Point a Deployment with that oversized request at `by-hand` and watch the
   `Failed` count climb. The ReplicaSet keeps creating replacements and the script keeps binding them.
   Stop it, count the corpses, and name the two fixes: a scheduler that filters on resources, or
   requests that fit. Gate on the learner having stopped the loop, not on a Pod count.

## Must resolve before building

- **The exact `status.reason` the kubelet writes for an untolerated `NoExecute` taint.** The predicate
  reuses the scheduler plugin's error, but the string the learner sees in `kubectl get pod` hasn't been
  observed yet. Quote it from a live run.
- **What happens to a Pod bound to a nonexistent node.** The expectation is that PodGC deletes it as an
  orphan after a quarantine period of roughly 40s. If so, that's a better ending for step 2 than "it
  stays `Pending`". Measure it, and confirm the Pod is *deleted* rather than marked `Failed`.
- **How fast the step 5 loop runs.** One `Failed` Pod per loop iteration is the expectation. Set the
  script's interval so the count is obvious within a minute but can't reach the hundreds before the
  learner reads the step. Also check whether the ReplicaSet backs off on repeated failures, because
  that changes what the learner watches.
- Whether `kubectl get` prints `SchedulingGated` on the backend's kubectl version, as the
  pod-scheduling-readiness docs show. Step 1's comparison leans on it.

## Cross-links

- [`troubleshooting/control-plane`](../../troubleshooting/control-plane/) step 1: same no-events
  symptom, different cause. Step 1 here should say so.
- [`workloads/scheduling-constraints`](../../workloads/scheduling-constraints/): the Pods the default
  scheduler refused. This lab is about Pods it never saw.
- [`scheduler-profiles`](../scheduler-profiles/) explains why a second *profile* beats a second
  scheduler process: one cache, so two schedulers can never both count the same free CPU.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted. See the conventions in `ckne/README.md`.
