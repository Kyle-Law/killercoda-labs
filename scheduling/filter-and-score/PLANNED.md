# Filter, Score, and the Node Nobody Looked At

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **Topic** | How the default scheduler decides: filter plugins, weighted score plugins, node sampling |
| **CKA relevance** | Workloads & Scheduling: reading `FailedScheduling`, `preferred` vs `required` affinity |
| **Proposed backend** | `kubernetes-kubeadm-1node` + KWOK (about 12 fake nodes in 3 zones; about 500 for step 4) |
| **Feasibility** | Blocked on the KWOK spike in [`../README.md`](../README.md). Two claims to verify |

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
   `"Calculated node's final score for pod"`. Reproduce one node's final score by hand from the
   default weights.
3. **A vote you lost.** A Deployment prefers zone `a` with `weight: 100`. Scale it up and count Pods per
   zone. Some land elsewhere, and the score logs show which plugins outvoted the preference.
   `PodTopologySpread`'s system default constraints are the ones nobody wrote. Gate: the learner names
   the plugin that tipped a specific Pod, read from the logs.
4. **The node nobody looked at.** Scale fake nodes to about 500, mark one as clearly best (the only one
   matching a preferred term), and schedule 20 Pods. Far fewer than 20 land on it. Above 100 nodes the
   scheduler stops filtering once it has *enough* feasible nodes, about 46% of them at 500. The
   rotating start index puts the best node in the window only some of the time. **The scheduler picks
   the best node it looked at.** The fix, `percentageOfNodesToScore: 100`, is a one-liner in
   [`scheduler-profiles`](../scheduler-profiles/). Name it here, apply it there.

## Must resolve before building

- **Whether the per-plugin score in the `V(10)` log is before or after the plugin's weight.** Step 2's
  arithmetic depends on it, and the answer is in `RunScorePlugins`, which applies weights after
  normalising. Confirm against the logged numbers, not the source.
- **The numbers for step 3.** Whether preferred affinity loses at all depends on replica count, node
  sizes and spreading. Find a setup where the effect is unmistakable. If `weight: 100` wins at every
  sensible scale, rewrite the step as "what it took to make it lose".
- **`--vmodule` on the pinned version.** It only works with the text log format, and the pattern must
  match the source file basename. Confirm the file still exists and that its lines appear.
- **Step 4's node count**, which is set by the KWOK ceiling measured in the spike. If 500 isn't viable,
  use the smallest count above 100 that gives an obvious miss rate, and work out the expected
  percentage for that count rather than quoting 46%.
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
