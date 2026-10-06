# The Zone You Can't Use Is Still Counted

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **Topic** | `topologySpreadConstraints`: skew, domains, and what the scheduler counts |
| **CKA relevance** | Workloads & Scheduling: spreading replicas across failure domains |
| **Proposed backend** | `kubernetes-kubeadm-1node` + KWOK (3 zones × 2 fake nodes) |
| **Feasibility** | Blocked on the KWOK spike. Steps 3 and 4 need their numbers found on a live cluster |

## What it teaches

[`workloads/scheduling-constraints`](../../workloads/scheduling-constraints/) step 3 spreads with
required anti-affinity and meets its limit: one Pod per node, then `Pending`. Topology spread is the
grown-up version. You allow a skew instead of forbidding co-location. But skew is computed over
*domains*, and which nodes count as a domain is decided by two policy fields most people never set.

## The finding at its heart

**A zone you cannot schedule into still counts as an empty zone.** `nodeTaintsPolicy` defaults to
`Ignore`, so tainted nodes still define domains. A tainted zone holds zero matching Pods forever, which
pins the global minimum at zero. With `maxSkew: 1` and `DoNotSchedule`, the other zones can each take
one Pod and no more. Everything after that is `Pending`, on a cluster with plenty of room.
`nodeTaintsPolicy: Honor` fixes it in one line. (`nodeAffinityPolicy` already defaults to `Honor`,
which is why this happens with taints and not with a `nodeSelector`.)

## Step outline

1. **Skew, by counting.** Six replicas over three zones, `maxSkew: 1`, `DoNotSchedule`: 2/2/2. Scale to
   seven and predict which zones may take the seventh. Gate on the prediction in `/root/answers`.
2. **The empty zone.** Taint zone `c`'s nodes `NoSchedule` (it's reserved for other work, as a GPU pool
   would be) and scale up. Two Pods run and the rest are `Pending`. Read the `FailedScheduling` message,
   explain it, then fix it with `nodeTaintsPolicy: Honor`. Contrast with `minDomains`, which forces the
   same `Pending` deliberately, for a cluster autoscaler to act on.
3. **Spread survives scheduling, not rollouts.** A rolling update of a well-spread Deployment. During
   the rollout the new ReplicaSet's Pods are spread *counting the old ones*, because the selector
   matches both. When the old Pods go, the new set is skewed. `matchLabelKeys: [pod-template-hash]`
   makes each revision spread against itself.
4. **Nobody spreads on the way down.** Scale from 9 (3/3/3) to 4. The ReplicaSet picks which Pods to
   delete by its own ranking, with no knowledge of zones, and the constraint isn't consulted because
   nothing is being scheduled. Leave the learner with the skew and the question of who fixes it. The
   answer is [`descheduler`](../descheduler/).

## Must resolve before building

- **That tainted nodes really do pin the global minimum on the pinned version.** That's the documented
  meaning of `nodeTaintsPolicy: Ignore`, and the whole lab rests on it. Reproduce it first.
- **Step 3 numbers.** The skew a rollout produces depends on `maxSurge`, `maxUnavailable`, replica count
  and the order old Pods are removed. Find a setup where the skew after rollout is obvious and
  repeatable, not occasional.
- **Step 4's outcome.** ReplicaSet scale-down ranks Pods partly by how many siblings share their node,
  then by readiness and age. On KWOK, with one Pod per fake node, the ties may resolve the same way
  every time, or randomly. If the result isn't reliably skewed, construct the starting placement so
  that it is.
- Whether KWOK nodes need `topology.kubernetes.io/zone` set in the node template or added after
  creation. That's a detail of the shared init.

## Cross-links

- Starts where [`workloads/scheduling-constraints`](../../workloads/scheduling-constraints/) step 3
  stops.
- The default constraints that outvoted a preference in [`filter-and-score`](../filter-and-score/)
  step 3 are these, applied implicitly. Cluster-wide defaults are configured in
  [`scheduler-profiles`](../scheduler-profiles/).
- Step 4 hands off to [`descheduler`](../descheduler/) (`RemovePodsViolatingTopologySpreadConstraint`).

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted. See the conventions in `ckne/README.md`.
