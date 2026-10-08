# scheduling

The scheduler as the subject, not as scenery.

Scheduling already shows up across this repo, always as the means to something else.
[`workloads/scheduling-constraints`](../workloads/scheduling-constraints/) reads three `FailedScheduling`
events and fixes three Pods. [`ai-workloads/gpu-scheduling`](../ai-workloads/gpu-scheduling/) uses
extended resources, quota and one round of preemption to teach accelerator scarcity.
[`gang-scheduling`](../ai-workloads/gang-scheduling/) puts Kueue in front of the scheduler, and
[`dra-devices`](../ai-workloads/dra-devices/) replaces the device counter it reads.
[`troubleshooting/control-plane`](../troubleshooting/control-plane/) step 1 breaks the scheduler's static
Pod. Each of those treats `kube-scheduler` as a black box that either places the Pod or doesn't.

**These labs open the box, then change what's inside it.** The first four show what the scheduler is
and how it decides: a client that writes one field, a filter that reports one reason per node, a score
built from weighted votes, and spreading and preemption past the basics. The last four customise it,
from cheapest to most invasive: configuration profiles, an HTTP extender, out-of-tree plugins, and the
descheduler that revisits what the scheduler will never revisit.

## Status

Three labs built. The rest are `PLANNED.md` design specs with deliberately no `index.json` — Killercoda
only indexes directories that have one, so nothing unfinished here can be published by accident.

| # | Lab | Status | Finding |
|---|---|---|---|
| 1 | [`scheduler-by-hand`](scheduler-by-hand/) | **Built** | The scheduler is not a gate. Anything that writes `spec.nodeName` skips it, and the kubelet re-checks only some of what it skipped. A `NoExecute` taint is enforced twice and leaves no Pod to inspect |
| 2 | [`filter-and-score`](filter-and-score/) | **Built** | `FailedScheduling` gives one reason per node, the first one; a `weight: 100` preference is worth 200 and one soft taint costs 300; and above 100 nodes the scheduler picks the best node *it looked at* |
| 3 | [`topology-spread`](topology-spread/) | Planned — ready (KWOK spike done) | A zone you cannot schedule into still counts as an empty zone |
| 4 | [`preemption-in-depth`](preemption-in-depth/) | Planned — ready, two claims to verify | Preemption picks victims, not a node. The winner is only *nominated*, and it waits out every victim's grace period |
| 5 | [`scheduler-profiles`](scheduler-profiles/) | **Built** | Adding `--config` silently disables the `--kubeconfig` flag on the line above it, and a `bin-packing` profile that does not pack is being outvoted by a default nobody wrote |
| 6 | [`scheduler-extender`](scheduler-extender/) | Planned — ready (KWOK spike done) | `ignorable` decides which outage you get: no scheduling at all, or no policy, reported in one `Info` log line |
| 7 | [`descheduler`](descheduler/) | Planned — **verify first** (KWOK is ready; the descheduler is not) | Give the scheduler and the descheduler different goals and they move the same Pod back and forth forever |
| 8 | [`load-aware-scheduling`](load-aware-scheduling/) | Planned — **verify first**, heaviest | The scheduler places on requests, not usage. A node at 100% CPU looks empty |

### What building the first one settled

Run end to end on a two-node kind cluster (Kubernetes v1.37.0, the init and every check executed as
root inside the control-plane container, and every command in the Solution blocks extracted from the
markdown and run as written). Five things the spec had wrong or open, all now load-bearing:

- **`NoExecute` is enforced twice, and the Pod does not survive to be inspected.** The spec said the
  kubelet refuses it and it goes `Failed`. What happens: the kubelet writes `Predicate TaintToleration
  failed`, the control plane's `taint-eviction-controller` writes `Marking for deletion`, and the Pod
  is gone within seconds. Five trials out of five produced both events. The check therefore gates on the
  kubelet's event rather than on a Pod, because events outlive the object they are about.
- **There are three different outcomes, not one.** Bound by hand against a `nodeSelector`, the kubelet
  rejects it and the Pod **stays** as `Failed` / `NodeAffinity`. Against a `NoSchedule` taint, nothing
  objects and it runs. The spec's third rule, an oversized CPU request, became step 5 because its
  outcome (`Failed` / `OutOfcpu`, never rescheduled) is the one that feeds a loop.
- **"No `FailedScheduling` event" was the weaker discriminator.** A Pod no scheduler has looked at has
  no events **and no `PodScheduled` condition at all**; a gated or refused Pod has the condition with a
  reason. That is on the Pod itself, so step 1 is built on it.
- **The orphaned Pod is deleted, not failed, in 52–70 seconds.** The spec expected about 40; PodGC
  runs every 20s and quarantines for 40s. `Binding` validates nothing about the node, and nothing
  records the deletion: no event, no condition.
- **The runaway has no back-off.** Failed Pods climbed at about 1.4 a second (82 in a minute) and
  84 were still there after the loop stopped. Failed Pods are not collected until 12500 exist.

One thing learned that was not in the spec: `pkill -f by-hand.sh` run from a `bash -c` string kills
the shell running it, because the pattern matches its own command line. It is harmless in a learner's
interactive terminal, and it is why the test harness uses `pkill -f '[b]y-hand.sh'`.

Observed incidentally and worth carrying into [`filter-and-score`](filter-and-score/): a Pod with a
`nodeSelector` no node satisfies got `1 node(s) didn't match Pod's node affinity/selector, 1 node(s)
had untolerated taint(s)`. The control-plane node lacked the label *and* carried the taint, and
reported only the taint, which is first-failure-only filtering seen on a live cluster.

### What building `scheduler-profiles` settled

Run end to end on a fresh kind cluster (Kubernetes v1.37.0, twelve fake nodes from `kwok-nodes.sh`),
the real init executed as root in the control-plane container and every Solution block extracted from
the markdown and run as written. The spec was wrong or silent on six things:

- **The second failure is better than the spec expected.** With `--config` set and mounted, the
  scheduler logs `Neither --kubeconfig nor --master was specified` while
  `--kubeconfig=/etc/kubernetes/scheduler.conf` is on its own command line. The spec guessed at a
  missing `KUBERNETES_SERVICE_HOST`; the real message flatly contradicts the manifest, and ends in
  `invalid configuration: no configuration has been provided, try setting KUBERNETES_MASTER environment variable`.
  The first failure is `open /etc/kubernetes/scheduler-config.yaml: no such file or directory`, for a
  file that is plainly on the host.
- **The effective config is not logged, but it is served.** The spec's check was to read it from the
  startup log. At default verbosity there is nothing: no profile, no `percentageOfNodesToScore`. The
  scheduler serves it at `/configz` on its secure port, defaults applied, and it needs a client
  certificate (anonymous gets 403). `admin.conf` carries one. Every check in the lab gates on that, so
  it can tell "you edited the file" from "the process loaded it".
- **Unknown fields are refused, not ignored.** Strict decoding, naming the field:
  `unknown field "percentageOfNodeToScore"`, and inside plugin args
  `unknown field "scoringStrategy.resourcess"`. A mismatched queue sort was not reachable with
  in-tree plugins, since `PrioritySort` is the only one; a profile *without* one is refused
  (`only one queue sort plugin required ... but got 0`), as are duplicate and missing names.
- **A bin-packing profile that does not pack is the lab's real finding, and the spec had it as a
  side note.** `MostAllocated` earned an occupied node 4 points (11 against 7) and the built-in
  `PodTopologySpread` took 28 to 54 away, so twelve replicas still used twelve nodes. The built-in
  spreading is applied to a Deployment's Pods and not to a bare Pod, which the plugin skips. Switching
  it off for that profile (`defaultingType: List`, `defaultConstraints: []`) put twelve on one node
  while `default-scheduler` still used twelve. **Anything that needs `bin-packing` to pack, such as
  [`descheduler`](descheduler/), needs this.**
- **`profiles` is the whole list, not a list of additions.** Naming only `bin-packing` starts cleanly
  and serves `/configz`, and every Pod that names no scheduler is silently orphaned: `Pending`, no
  events, no `PodScheduled` condition, nothing in the log. It is step 1 of `scheduler-by-hand` reached
  by a config change. Built as step 3.
- **The "restart a static Pod" trick the CKA teaches stops working after a few crashes.** Moving the
  manifest away and back returns the *same Pod*: `kubernetes.io/config.hash` on the mirror Pod was
  identical across the round trip and changed with an annotation. So it inherits the crash back-off
  the earlier attempts built. Step 1's fix took 84 seconds, and the next restart landed inside a
  2m40s back-off and timed the helper out. `restart-scheduler` changes a harmless annotation instead:
  21 seconds, every time. This was found by the lab failing, not by reading about it.

Two behaviours the spec did not expect, both now in the lab text: a Pod that was `Pending` because no
profile answered for it is picked up the moment one does, and the scheduler's `-v` log never mentions
that it is ignoring such a Pod.

### What building `filter-and-score` settled

Run end to end on a fresh kind cluster (v1.37.0): the real init as root in the control-plane container,
every Solution block extracted from the markdown and run as written, and every check confirmed to fail
before its task, on each wrong state and each wrong answer, and pass after. It also **corrected the
spike that unblocked it**, which is the most important thing it found:

- **A node that reports `Ready` is not schedulable, and `kwok-nodes.sh` returned before it was.** New
  nodes keep `node.kubernetes.io/not-ready:NoSchedule` until the node lifecycle controller clears it,
  about five a second. The script returned after 4 seconds with 479 of 500 nodes still tainted. It
  now waits (250 nodes: 59s). This was found because a sampling count came out wrong: only 129 of 501
  nodes were feasible, not 230.
- **The batching finding from the spike is retracted.** It was measured on that unsettled fleet. Settled,
  batching on and off give the same spread (see *Observed on a cluster*). The lab does not touch it.
- **Step 3 is not the one the spec described.** The spec had a zone preference losing to default
  spreading. What the log showed was cleaner and more surprising: one untolerated `PreferNoSchedule`
  taint costs 300 (100 × `TaintToleration`'s weight of 3) and a `weight: 100` preference is worth 200
  (100 × `NodeAffinity`'s weight of 2), so **a soft taint beats the strongest preference there is**:
  6 of 6 replicas on the node, then 0 of 6, then 6 of 6 once they tolerated it. The default-spreading
  erosion (`PodTopologySpread` falling from 200 to 14, 671 against 672, so 18 of 20 at a dozen nodes)
  is in the recap as the baseline for step 4.
- **Step 4 uses 250 nodes, not 500.** Same effect, a minute to settle instead of two: 251 nodes gives
  `feasibleNodes=120` (a number that is not 100, so it cannot be mistaken for the percentage), 6 to
  11 of 20 on the preferred node and varying, against **16 every time** with
  `percentageOfNodesToScore: 100`. The fix is a one-line config change, which is why the lab's
  scheduler starts out reading a config file, as it does at the end of
  [`scheduler-profiles`](scheduler-profiles/).
- **The log line is `evaluatedNodes=120 feasibleNodes=120`**, not 251: the scheduler *looked at* only
  120 nodes before it stopped. The 296 to 396 readings in the spike were the unsettled fleet.
- **Step 1's prediction is checkable against the cluster, not against a constant.** The check reads the
  newest `FailedScheduling` message and compares the learner's `cpu=` and `selector=` counts to it, so
  it stays right if the fleet is changed. The `preemption:` half of the message is explained: "not
  helpful" for nodes where eviction cannot change a taint or a selector, "no victims" for full nodes
  holding Pods of the same priority.


The numbers give the **learning order**. The build order is different (see [Build order](#build-order)).

## The prerequisite: fake nodes

On one or two nodes, most of what the scheduler does is invisible. The score plugins never disagree,
spreading has one domain, and `percentageOfNodesToScore` has no effect below 100 nodes. Labs 2, 3, 6
and 7 need many nodes, and the backends offer two.

**[KWOK](https://kwok.sigs.k8s.io/)** solves this. Its controller makes `Node` objects look `Ready` and
reports any Pod bound to them as `Running`, with no kubelet behind either. The real `kube-scheduler`
places Pods on them with nothing faked on its side. [`kwok-nodes.sh`](kwok-nodes.sh) is the tested
init: `kwok-nodes.sh 30` installs KWOK v0.8.0 and ends with exactly 30 fake nodes spread over three
zones. Each lab that needs it copies the file into its own `init/`, the same way `certificate-renewal`
reuses `issuers-and-trust`'s init.

Pods that should land on fake nodes need **both** `nodeSelector: {type: kwok}` and a toleration for
`kwok.x-k8s.io/node`. The selector matters as much as the toleration, see below.

What KWOK cannot fake, and which lab therefore needs a real kubelet:

| Needs a real kubelet | Why | Lab |
|---|---|---|
| Kubelet admission (`OutOfcpu`, `NoExecute` taints) | No kubelet, no admission. A fake node accepts anything bound to it | 1 |
| Graceful termination | A victim's grace period is the whole point of step 1 | 4 |
| Actual CPU usage | Nothing to measure | 8 |

### What the KWOK spike settled

Run on kind, Kubernetes v1.37.0, one untainted control-plane node, Cilium 1.19.7 with
`kubeProxyReplacement=true` (the backend's shape), Docker given 12 CPUs and 10 GB. Every claim below
was observed, not inferred.

- **Cilium does not react to fake nodes.** With 30 of them it ran 60 fake `cilium` and `cilium-envoy`
  Pods, all `Running` because KWOK invents the status, while the real agent stayed at 33/33 controllers
  healthy and 1/1 nodes reachable, there was still exactly one `CiliumNode`, and the operator logged no
  errors or warnings. Harmless at 30. At 500 it would be 1000 fake Pods, which is what the next point avoids.
- **Keeping DaemonSets off needs no patching.** Both Cilium DaemonSets tolerate every taint, so the
  `NoSchedule` taint does nothing to them, but both carry `nodeSelector: kubernetes.io/os=linux`. The
  fake nodes are labelled `kubernetes.io/os=fake` and never match. Two alternatives were tried and
  rejected: the chart's own `cilium.io/no-schedule` label (honoured by `cilium-envoy`, **ignored by the
  agent**, whose Pod stayed put) and a `nodeAffinity` patch (works, but restarts the real agent and
  *replaces* envoy's existing affinity). A DaemonSet with no such selector would still get a fake Pod
  per node.
- **System Pods stay off.** CoreDNS scaled to 12 put all 12 on the real node.
- **The `ImageLocality` bias is real but modest.** Twenty tolerating Pods with no `nodeSelector`: 4
  landed on the real node against a fair share of under one. With `nodeSelector: type: kwok`, 30 Pods
  went one per fake node, exactly.
- **A node that reports `Ready` is not yet schedulable, and the gap grows with the fleet.** A new
  node carries `node.kubernetes.io/not-ready:NoSchedule` until the node lifecycle controller removes
  it, and it removes them one at a time at about **five a second**. `kwok-nodes.sh` first returned
  after 4 seconds with 479 of 500 nodes still tainted. It now waits for the taint to clear:

  | Fake nodes | `kwok-nodes.sh` returns after | Idle API server / etcd, settled |
  |---|---|---|
  | 12 | 7s | negligible |
  | 250 | 59s | 3–16% / 2–7% of one CPU, 26 lease writes a second |
  | 500 | about 110s (measured clearing, not end to end) | about double that, not measured settled |

  An earlier version of this section reported 500 nodes "created in 8.9s", a third of a CPU idle, and
  sampling results to match. **All of it measured a fleet whose taints had not cleared**, so fewer
  than 230 nodes were feasible and nothing was skipped. See the retraction under *Observed on a
  cluster*. Scale up only for the step that needs it, expect to wait, and wipe afterwards.
- **Delete fake nodes by label, never by name.** `kubectl delete nodes -l type=kwok` removed 280 nodes
  in 2.8s; deleting them by name ran at about a node a second. `kwok-nodes.sh` resizes by wiping and
  recreating.
- **Measure from inside, not through Docker Desktop.** The first ceiling run, driven from the host, saw a
  150-node apply take 1083 seconds. It was not Kubernetes: the same operation inside the container took
  5 seconds. A learner on a Killercoda VM does not have that hop.

**Still open, so say it before building on it:**

- **Not run on Killercoda.** Everything above is kind with a generous Docker allocation. The Killercoda
  VM is smaller; the settled idle cost at 250 nodes and the time to settle are the numbers to check.
- **The `os=fake` trick was proven on a surrogate, not on live Cilium.** A DaemonSet with Cilium's exact
  selector and tolerations got `desired=1`; one without a selector got `desired=31`. The live Cilium
  DaemonSets' selectors were read off the API, and their health under fake nodes was observed, but the
  final combination was not re-run: the fresh cluster's image pulls from `quay.io` stalled for
  17 minutes, so the script test used a plain cluster instead. Re-run it once against a Cilium cluster.
- **One unexplained empty result.** Immediately after recreating 60 nodes, a label applied to one of them
  had no effect (a test saw 0 of 20 Pods on it, then 17 of 20 on a rerun). The script waits for Ready
  and settles for two seconds; a lab that depends on a node label straight after a resize should check
  it first.

## Observed on a cluster by the spike

Kind, Kubernetes v1.37.0, the scheduler static Pod edited the way a lab would edit it:

- **`/configz` serves the running configuration**, defaults applied, to a client certificate. It is how a check can tell what the process loaded from what the file says.
- **`--vmodule=schedule_one=10` works**, and logs every plugin's score for every node plus a final
  total. **The logged scores are already weighted**: `TaintToleration` logs 300 (3 × 100), and the
  plugin lines sum exactly to the final score (300 + 98 + 0 + 0 + 0 = 398).
- **Only plugins with something to say vote.** A bare Pod with no constraints was scored by five
  (`TaintToleration`, `NodeResourcesFit`, `VolumeBinding`, `DynamicResources`, `ImageLocality`). The
  others skip.
- **Node sampling is exact and visible.** At 500 nodes `feasibleNodes=230` on every Pod, which is 46%
  (`50 − 500/125`). The line is `"Successfully bound pod to node"` and is `V(2)`, so **it is absent at
  default verbosity**.
- **Retracted: "the default scheduler batches identical Pods and it changes the result".**
  `OpportunisticBatching` (KEP-5598) does exist, Beta and on by default since v1.35. But the result
  that appeared to show its effect (20 replicas, 501 nodes: 12, 12, 12 with it on, 8, 9, 8 with it
  off) was measured while the nodes' not-ready taints were still clearing and does not reproduce.
  With the fleet fully settled, 6 trials each: batching **on** 8, 9, 11, 9, 8, 13; batching **off**
  13, 10, 7, 9, 12, 11. Both about ten, and a 7–13 spread that swamps any difference. **No measurable
  effect on this experiment.** The mechanism is read from source, not demonstrated.
- **Sampling is real, and one setting undoes it.** At 251 settled nodes the log says
  `feasibleNodes=120` (48% of 251, from `50 − 251/125`) and 20 replicas preferring one node put
  **6, 11, 11, 9, 11, 7** on it. With `percentageOfNodesToScore: 100` the log says `feasibleNodes=250`
  and the count is **16 in all six trials**. Below 100 nodes there is no sampling, and the same
  experiment gives **18 of 20, five trials out of five**.
- **A preference is not a guarantee even with nothing in the way, and the log says why.** At 12 nodes
  the preferred node scored `NodeAffinity` 200 but `PodTopologySpread` 14 (against 200 on an empty
  node) and `NodeResourcesFit` 83 (against 98), for 671 against 672: it lost by one point. The built-in
  spreading penalty grows with every replica on the node until it overtakes the preference.
- **A soft taint outvotes a `weight: 100` preference.** One untolerated `PreferNoSchedule` taint on
  the preferred node: `TaintToleration` 0 against 300 elsewhere, `NodeAffinity` 200 against 0. The
  preference is worth 200 and the taint costs 300 (100 × the plugin weights of 2 and 3). Six
  replicas: **6 of 6** reached the node, then **0 of 6** with the soft taint, then **6 of 6** again
  once they tolerated it.
- **A preferred term's `weight` only matters against other preferred terms.** The scheduler scales the
  best-matching node to 100, so a lone term scored 200 on the matching node at `weight: 1` and at
  `weight: 100` alike (6 of 6 Pods on the node at weights 1, 10, 50 and 100). With two terms the weaker
  one is scaled against the stronger: weight 25 beside weight 100 scored 50. So "weight 100" is not a
  strong wish; it is the only wish.
- **Plugin weights decide the soft-taint contest, and they can be changed in a profile.** With the soft
  taint on the preferred node and `weight: 100`, six replicas, `NodeAffinity` plugin weight 2, 3, 4, 5:
  **0, 0, 3, 6** on the node. `TaintToleration` plugin weight 3, 2, 1: **0, 1, 3**. The syntax that works
  is `plugins.multiPoint.enabled: [{name: NodeAffinity, weight: 5}]`, confirmed in `/configz`. The first
  Pod's margin is `100 × (NodeAffinity weight − TaintToleration weight)`, and the later replicas erode
  it, which is why a margin of +100 (weight 4) still gave only 3 of 6.
- **`FailedScheduling` reports one reason per node, and the order is the filter order.** A fleet of
  13 nodes failing four different ways gave `2 Insufficient cpu, 3 node(s) didn't match Pod's node
  affinity/selector, 8 node(s) had untolerated taint(s)`; tolerating the taint gave `5 Insufficient
  cpu, 8 node(s) didn't match … selector`. Taint, then selector, then resources: the 8 tainted nodes
  had been hiding five cpu failures and three selector ones.

## Confirmed from upstream source, not yet on a cluster

Read from `kubernetes/kubernetes` at `master` and the v1.37 `kube-scheduler` flag reference in
October 2026. These are the mechanisms the findings rest on. Re-check each against the pinned version
before a lab quotes it, and reproduce the behaviour before writing it down:

- **Default score weights:** `TaintToleration` 3; `NodeAffinity`, `PodTopologySpread`,
  `InterPodAffinity`, `DynamicResources` 2; `NodeResourcesFit`, `NodeResourcesBalancedAllocation`,
  `ImageLocality` 1 (`pkg/scheduler/apis/config/v1/default_plugins.go`).
- **Filtering stops at the first plugin that rejects a node.** `RunFilterPlugins` returns on the first
  non-success status, so each node in a `FailedScheduling` message carries one reason, in plugin order.
- **The kubelet re-checks `NoExecute` taints only**, and skips even that for static Pods:
  `// Kubelet is only interested in the NoExecute taint.` (`pkg/kubelet/lifecycle/predicate.go`).
- **Extender scores are scaled into the plugin range:** `score * weight * (MaxNodeScore / MaxExtenderPriority)`,
  so an extender's 0–10 lands on the same 0–100 scale as plugins.
- **An extender with empty `managedResources` receives every Pod**, and an ignorable extender that
  fails is skipped with an `Info`-level log line, with no event and no warning.
- **Node sampling never applies below 100 nodes** (`minFeasibleNodesToFind = 100`), and never drops
  below 5%. The budget is computed from the candidate list, which a PreFilter may have narrowed, not
  from all nodes (`pkg/scheduler/algorithm.go`).
- **`--kubeconfig` is ignored when `--config` is set**, along with `--kube-api-qps`, `--kube-api-burst`,
  `--kube-api-content-type`, `--profiling` and `--contention-profiling`.

## Build order

Chosen by what unblocks what, not by learning order.

1. ~~**`scheduler-by-hand`**~~ — **built**. Five steps on `kubernetes-kubeadm-2nodes`: three Pods
   that are `Pending` for three different reasons, a `Binding` POSTed by hand, a sixteen-line bash
   scheduler, three rules skipped and three different enforcers, and a runaway of `Failed` Pods with no
   back-off.
2. ~~**The KWOK spike**~~ — **done**: [`kwok-nodes.sh`](kwok-nodes.sh), and the results above. Labs 2,
   3 and 6 are unblocked. Lab 7 still needs the descheduler checked against a v1.37 cluster.
3. ~~**`scheduler-profiles`**~~ — **built**. Four steps on `kubernetes-kubeadm-1node` with twelve fake
   nodes. It leaves behind a scheduler started with `--config`; labs 2, 6 and 7 can copy its
   `restart-scheduler` and `configz` helpers, and the manifest edits from its step 1.
4. ~~**`filter-and-score`**~~ — **built**: a fleet that fails four ways, per-plugin scores, a soft taint
   beating a weight-100 preference, and sampling at 250 nodes. Then **[`topology-spread`](topology-spread/)**,
   the default spreading that wore the preference out, written on purpose.
5. **[`scheduler-extender`](scheduler-extender/)**: needs no third-party image, only `python3` on the
   host.
6. **[`preemption-in-depth`](preemption-in-depth/)**: cheap to build, and the least urgent, because
   `gpu-scheduling` step 4 already covers the basics.
7. **[`descheduler`](descheduler/)** and **[`load-aware-scheduling`](load-aware-scheduling/)**, last.
   Both depend on third-party components whose compatibility with the backend's Kubernetes version
   is unproven.

### Considered and deferred

- **Writing a scheduler plugin in Go.** This is the real end of the customisation road, but compiling
  `kube-scheduler` means downloading `k8s.io/kubernetes`'s module graph and building it on a lab VM.
  Expect minutes of wall clock and gigabytes of RAM. Doable only if a prebuilt image is published
  somewhere the lab can pull from, which is a hosting decision rather than a lab design. Revisit if
  [`kube-scheduler-wasm-extension`](https://github.com/kubernetes-sigs/kube-scheduler-wasm-extension)
  matures enough to load a plugin into a stock image.
- **Coscheduling (`scheduler-plugins`).** Gang scheduling at the scheduler's `Permit` point, which
  holds resources while it waits. That makes it a good contrast to Kueue holding nothing, but it
  belongs as a step in [`gang-scheduling`](../ai-workloads/gang-scheduling/), not as a lab here.
- **`kube-scheduler-simulator`.** A web UI that shows per-plugin scores. Too heavy for a lab VM, and
  the `V(10)` log lines show the same numbers on the real scheduler.

## Conventions

Same as everywhere else in this repo. See [`ckne/README.md`](../ckne/README.md) for the ones that bite
hardest:

- **Scenarios index exactly two levels deep:** `scheduling/<scenario>/index.json` and nothing deeper.
- **Every check must say what it wanted.** Each `verify.sh` writes its reason to `/root/.check`, and
  each init installs the `why` helper that prints it.
- **`mkdir -p /root/answers`** in any init whose steps write a finding there.
- **Back up the static Pod manifest before any step edits it.** Labs 1, 2, 5, 6 and 7 all touch
  `/etc/kubernetes/manifests/kube-scheduler.yaml`. A broken scheduler leaves every new Pod `Pending`
  with no events, which includes the Pods a `verify.sh` creates to test the learner's work. Each init
  copies the original to `/root/kube-scheduler.yaml.orig`, as `troubleshooting/control-plane` does,
  and each step's text says how to restore it.
