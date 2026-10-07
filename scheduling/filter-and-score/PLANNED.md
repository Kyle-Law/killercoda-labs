# Filter, Score, and the Node Nobody Looked At

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **Topic** | How the default scheduler decides: filter plugins, weighted score plugins, node sampling |
| **CKA relevance** | Workloads & Scheduling: reading `FailedScheduling`, `preferred` vs `required` affinity |
| **Proposed backend** | `kubernetes-kubeadm-1node` + KWOK (about 12 fake nodes in 3 zones; about 500 for step 4) |
| **Feasibility** | Ready. The KWOK spike is done: init is [`../kwok-nodes.sh`](../kwok-nodes.sh). Step 4 was redesigned by what the spike found (below) |

## What it teaches

[`workloads/scheduling-constraints`](../../workloads/scheduling-constraints/) reads one
`FailedScheduling` event per Pod, each with one cause. That's the easy case. With a dozen nodes that
fail for different reasons, the message reads like a histogram, and it is one. But it's a histogram of
*first* failures. And when every node passes, the choice among them comes from about eight plugins,
each casting a weighted vote. Most of those votes come from rules the Pod's author never wrote.

## The finding at its heart

**`FailedScheduling` reports one reason per node: the first filter that rejected it.** Filtering stops
at the first plugin that says no. `TaintToleration` runs before `NodeResourcesFit`, so a node that is
tainted *and* full only ever says "untolerated taint". Add the toleration, and the same nodes now say
`Insufficient cpu`, a reason that was true all along and never shown.

Second finding, for step 3: **`preferred` is a vote, not a preference.** A `weight: 100` node-affinity
term is normalised inside `NodeAffinity`'s own 0–100 range and multiplied by that plugin's weight of 2.
It then competes with resource balancing, and with default topology spreading that applies to every
Deployment's Pods whether or not anyone wrote a constraint.

## Step outline

1. **Read the message as a histogram.** Init builds fake nodes that fail in different ways: tainted,
   full, wrong zone label, tainted *and* full. A Pod fits none of them. Count the reasons and check
   they sum to the node count. Then predict, in `/root/answers`, what the tainted-and-full nodes will
   say once the Pod tolerates the taint. Gate on the prediction. The step's text then lets the learner
   apply the toleration and see it.
2. **Turn the lights on.** Raise the scheduler's verbosity for one file only:
   `--vmodule=schedule_one=10` on the static Pod, not `-v=10` cluster-wide. Schedule one Pod and read
   `"Plugin scored node for pod"` for every plugin on every node, then
   `"Calculated node's final score for pod"`. Reproduce one node's final score by hand. **The logged
   scores are already multiplied by the plugin's weight**, so the arithmetic is a plain sum:
   `TaintToleration=300` (3 × 100) `+ NodeResourcesFit=98 + VolumeBinding=0 + DynamicResources=0 +
   ImageLocality=0 = 398`, the final score logged for the same node. Only five plugins voted for a bare
   Pod. The ones with nothing to say about it skip, so *which plugins vote depends on the Pod*, which is
   a finding in its own right.
3. **A vote you lost.** A Deployment prefers zone `a` with `weight: 100`. Scale it up and count Pods per
   zone. Some land elsewhere, and the score logs show which plugins outvoted the preference.
   `PodTopologySpread`'s system default constraints are the ones nobody wrote. Gate: the learner names
   the plugin that tipped a specific Pod, read from the logs.
4. **The node nobody looked at.** Scale fake nodes to 500 and mark one as clearly best (the only one
   matching a preferred term). Above 100 nodes the scheduler stops filtering once it has *enough*
   feasible nodes, and at 500 that number is exactly **230** (46%, from `50 − 500/125`). **The scheduler
   picks the best node it looked at.** The fix, `percentageOfNodesToScore: 100`, is a one-liner in
   [`scheduler-profiles`](../scheduler-profiles/). Name it here, apply it there.

   **Measured in the spike**, 20 identical replicas preferring one node, three trials each:

   | Setup | Pods that reached the preferred node |
   |---|---|
   | 61 nodes (below the threshold), batching on or off | **17 of 20**, every trial |
   | 501 nodes, `OpportunisticBatching` **off** | **8, 9, 8 of 20** |
   | 501 nodes, scheduler defaults | **12, 12, 12 of 20**, identical every time |

   Two things are in that table that the spec did not expect. **17, not 20, is the ceiling:** something
   erodes the preference once the node fills, and the step must say so or the baseline looks like a
   bug. And **the default scheduler batches identical Pods**: `OpportunisticBatching` has been Beta and
   on by default since v1.35 and reuses scoring work across Pods with the same signature, which is why
   a Deployment's replicas give the same answer three times running and a smaller miss rate than
   sampling alone. A learner testing this with a Deployment would be measuring batching and drawing
   conclusions about sampling. The step has to either turn batching off
   (`--feature-gates=OpportunisticBatching=false`, itself worth a step: *identical Pods are not scored
   independently*) or make the Pods differ.

   The direct readout needs no counting: at `--vmodule=schedule_one=2` the bind line says
   `evaluatedNodes=296 feasibleNodes=230` (batching off) and `feasibleNodes=230` in every case. It is
   `V(2)`, so it is **absent at default verbosity**.

## Must resolve before building

- ~~Whether the per-plugin score in the `V(10)` log is before or after the weight.~~ **After.**
  `TaintToleration=300` is 3 × 100, and the plugin scores sum to the logged final score. Resolved.
- **The numbers for step 3.** Whether preferred affinity loses at all depends on replica count, node
  sizes and spreading. Find a setup where the effect is unmistakable. If `weight: 100` wins at every
  sensible scale, rewrite the step as "what it took to make it lose".
- ~~`--vmodule` on the pinned version.~~ `--vmodule=schedule_one=10` works on v1.37.0 and the score
  lines appear. Resolved.
- ~~Step 4's node count.~~ 500 is viable (see the spike in [`../README.md`](../README.md)), and
  `feasibleNodes=230` is observed exactly. Resolved.
- **The eroded ceiling.** Which plugin takes the preference from 20 of 20 down to 17 of 20 at 61 nodes
  is unattributed. Read it from the score logs, and for a Deployment's Pods rather than a bare Pod:
  `PodTopologySpread` skipped for the bare Pod and probably does not for a replica.
- **Why `evaluatedNodes` is 296–298 rather than 231** with batching off, and 360–396 with it on. The
  number is observed, not explained, so the step should quote `feasibleNodes` and leave
  `evaluatedNodes` alone until it is.
- The exact `FailedScheduling` wording at the pinned version, including the `preemption:` suffix,
  which step 1 should explain rather than ignore.

## Cross-links

- Builds directly on [`workloads/scheduling-constraints`](../../workloads/scheduling-constraints/),
  and should say so in the intro.
- Step 3's default spreading is the subject of [`topology-spread`](../topology-spread/).
- Step 4's fix, and the weights step 2 reads, are both configured in
  [`scheduler-profiles`](../scheduler-profiles/).

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted. See the conventions in `ckne/README.md`.
