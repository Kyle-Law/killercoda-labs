# The Decision Nobody Revisits

> **Status:** planned — **verify first**. This file is the design spec, not a lab.

| | |
|---|---|
| **Topic** | The descheduler: evicting Pods whose placement has gone stale, and what it can't do |
| **CKA relevance** | Beyond CKA. Explains why `IgnoredDuringExecution` is in the field name |
| **Proposed backend** | `kubernetes-kubeadm-1node` + KWOK; descheduler pinned, as a Job then as a Deployment |
| **Feasibility** | Verify first: the descheduler against KWOK nodes, and whether step 3's loop really happens |

## What it teaches

The scheduler decides once. New capacity arrives, labels change, a spread drifts during a scale-down,
and every running Pod stays exactly where it was put. Every affinity field says so in its name:
`requiredDuringScheduling`**`IgnoredDuringExecution`**. The descheduler is the separate component that
looks again. But it can only evict and hope, because placing the replacement is still the scheduler's
job.

## The finding at its heart

**Give the scheduler and the descheduler different goals and they move the same Pod back and forth
forever.** Run the scheduler's `bin-packing` profile (`MostAllocated`) from
[`scheduler-profiles`](../scheduler-profiles/) alongside the descheduler's `LowNodeUtilization`, which
spreads. The descheduler evicts from the busy node, the scheduler packs the replacement back onto it,
and the next descheduling cycle evicts it again. Both are working exactly as configured. The pairing
that agrees with bin-packing is `HighNodeUtilization`.

## Step outline

1. **Nothing moves.** Three fake nodes are packed. Add three empty ones: nothing moves. Relabel a node
   so a running Pod now violates its *required* node affinity: it keeps running. Gate: the learner
   records, in `/root/answers`, which field promised this.
2. **Look again.** Run the descheduler once as a Job with `RemovePodsViolatingNodeAffinity` and
   `LowNodeUtilization`. The violating Pod is evicted and rescheduled correctly, and the packed nodes
   drain onto the new ones. Read the descheduler's log to see which Pods it *refused* to evict and why:
   no owner, `kube-system`, local storage.
3. **The loop.** Switch the workload to the `bin-packing` profile and run the descheduler as a
   Deployment on a short interval. Count evictions of the same Deployment over a few cycles. Then fix
   it by changing one side to match the other. Gate: the eviction count stops rising.
4. **A PDB that stops everything, quietly.** A `PodDisruptionBudget` with `maxUnavailable: 0` on a
   skewed Deployment. The descheduler respects it strictly (unlike preemption in
   [`preemption-in-depth`](../preemption-in-depth/) step 2) and so does nothing, saying so only in its
   own log. Fix the skew left by [`topology-spread`](../topology-spread/) step 4 with
   `RemovePodsViolatingTopologySpreadConstraint` once the PDB allows it.

## Must resolve before building

- **Does the step 3 loop actually happen?** `LowNodeUtilization` evicts only when underutilised nodes
  exist to receive the Pods, and the descheduler's own node-fit check may decline to evict a Pod it
  predicts has nowhere better to go. If that check prevents the loop, the finding becomes "the
  descheduler second-guesses itself", which is weaker. Reproduce it before committing to the lab's
  framing.
- **The descheduler against KWOK.** It evicts through the Eviction API, KWOK must then finish the
  deletion, and the descheduler's utilisation is computed from requests. All of that should work, but
  nothing confirms it yet.
- **Pin a descheduler version compatible with the backend's Kubernetes minor.** The descheduler
  versions itself to match. Check its compatibility table rather than taking `latest`.
- The descheduler's log line for a PDB-blocked eviction, quoted verbatim, since step 4's check and text
  both depend on it.

## Cross-links

- Its scheduler side comes from [`scheduler-profiles`](../scheduler-profiles/) step 2.
- Fixes the skew [`topology-spread`](../topology-spread/) step 4 leaves behind.
- [`load-aware-scheduling`](../load-aware-scheduling/): `LowNodeUtilization` can also read real usage
  (`metricsUtilization`) instead of requests, the same distinction that lab is built on.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted. See the conventions in `ckne/README.md`.
