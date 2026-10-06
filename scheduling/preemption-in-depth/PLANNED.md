# Preemption Picks Victims, Not a Node

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **Topic** | PriorityClass and preemption past the basics: nomination, grace periods, PDBs, queue order |
| **CKA relevance** | Adjacent. PriorityClass is in scope, and these mechanics explain what the exam's happy path hides |
| **Proposed backend** | `kubernetes-kubeadm-1node`, with a fake extended resource for exact capacity (the `gpu-scheduling` trick) |
| **Feasibility** | Ready. No new components. Two claims to verify (below) |

## What it teaches

[`ai-workloads/gpu-scheduling`](../../ai-workloads/gpu-scheduling/) step 4 shows preemption working:
production arrives, research is evicted, production runs. That reads as instant and certain. It is
neither. Each victim is asked to terminate and given its full grace period. The preemptor only gets a
*nomination* while it waits, and that nomination protects the space against some Pods and not others.

## The finding at its heart

**Preemption picks victims, not a node.** The preemptor gets `status.nominatedNodeName` and stays
`Pending` until every victim has actually gone, which takes as long as the victims' grace periods.
Meanwhile, the nomination reserves the space only against Pods of *equal or lower* priority. A
higher-priority arrival can take it, and the preemptor has to start again.

## Step outline

1. **The wait.** Init advertises `example.com/slot: 4` on the node. Victims fill it with a priority of
   100 and `terminationGracePeriodSeconds: 90`. Their process is a `sleep` running as PID 1, which
   ignores `SIGTERM`, so they use the whole grace period. A preemptor arrives with a priority of
   1000000. Watch it sit `Pending` with `nominatedNodeName` set while the victims sit `Terminating`.
   Gate: the learner records how long the preemptor waited, and why.
2. **PDBs are a preference.** Put a `PodDisruptionBudget` with `minAvailable: 100%` on the victims and
   preempt again. They go anyway. The scheduler respects PDBs when it has a choice of victims and
   overrides them when it doesn't. Find the `DisruptionTarget` condition on a victim and read its
   reason. Contrast with `kubectl drain` against the same PDB, which refuses.
3. **Priority is two features.** `preemptionPolicy: Never` keeps one and drops the other. Two `Pending`
   Pods wait for space: a high-priority Pod that never preempts, and a low one. Free a slot and the
   high one goes first. Queue order is `PrioritySort`, and preemption is a separate decision.
4. **Who gets the hole.** While a preemptor waits on its nomination, submit a lower-priority Pod that
   would fit the space being freed. It can't take it, because nominated Pods of higher priority are
   counted as present when filtering. Submit a *higher*-priority one instead. It can take the space,
   and the original preemptor's nomination is now wrong.

## Must resolve before building

- **The exact `DisruptionTarget` reason on a preempted Pod** at the pinned version. The expectation is
  `PreemptionByScheduler`. Quote it from a live run.
- **Step 4's outcome.** The source comment says nominated Pods of equal or higher priority are counted
  when filtering an incoming Pod, so a higher-priority Pod can take the nominated space. What the
  original preemptor does next is the unverified part: whether it preempts again, re-nominates, or
  waits. Write the step around what actually happens.
- Whether a fake extended resource gives clean enough capacity accounting, or whether CPU requests
  sized to the node's allocatable are clearer to read. `gpu-scheduling` already proved the fake
  resource works for preemption.

## Cross-links

- Direct sequel to [`ai-workloads/gpu-scheduling`](../../ai-workloads/gpu-scheduling/) step 4, and
  should say so: this lab exists because that one showed the easy case.
- [`scheduler-by-hand`](../scheduler-by-hand/) step 1's gated Pods sit in a separate queue that
  preemption never considers.
- [`descheduler`](../descheduler/) is the other component that evicts for placement reasons. It honours
  PDBs strictly, which is the opposite of step 2.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted. See the conventions in `ckne/README.md`.
