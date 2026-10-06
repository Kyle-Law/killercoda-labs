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

One lab built. The rest are `PLANNED.md` design specs with deliberately no `index.json` — Killercoda
only indexes directories that have one, so nothing unfinished here can be published by accident.

| # | Lab | Status | Finding |
|---|---|---|---|
| 1 | [`scheduler-by-hand`](scheduler-by-hand/) | **Built** | The scheduler is not a gate. Anything that writes `spec.nodeName` skips it, and the kubelet re-checks only some of what it skipped. A `NoExecute` taint is enforced twice and leaves no Pod to inspect |
| 2 | [`filter-and-score`](filter-and-score/) | Planned — **needs KWOK** | `FailedScheduling` gives one reason per node, the first one. Fix it and a reason you were never shown appears |
| 3 | [`topology-spread`](topology-spread/) | Planned — **needs KWOK** | A zone you cannot schedule into still counts as an empty zone |
| 4 | [`preemption-in-depth`](preemption-in-depth/) | Planned — ready, two claims to verify | Preemption picks victims, not a node. The winner is only *nominated*, and it waits out every victim's grace period |
| 5 | [`scheduler-profiles`](scheduler-profiles/) | Planned — ready, one error message to capture | Adding `--config` silently disables the `--kubeconfig` flag on the line above it |
| 6 | [`scheduler-extender`](scheduler-extender/) | Planned — **needs KWOK** | `ignorable` decides which outage you get: no scheduling at all, or no policy, reported in one `Info` log line |
| 7 | [`descheduler`](descheduler/) | Planned — **verify first**, needs KWOK | Give the scheduler and the descheduler different goals and they move the same Pod back and forth forever |
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

The numbers give the **learning order**. The build order is different (see [Build order](#build-order)).

## The prerequisite: fake nodes

On one or two nodes, most of what the scheduler does is invisible. The score plugins never disagree,
spreading has one domain, and `percentageOfNodesToScore` has no effect below 100 nodes. Labs 2, 3, 6
and 7 need many nodes, and the backends offer two.

**[KWOK](https://kwok.sigs.k8s.io/)** solves this. Its controller makes `Node` objects look `Ready` and
reports any Pod bound to them as `Running`, with no kubelet behind either. The real `kube-scheduler`
places Pods on them with nothing faked on its side, so thirty nodes in three zones cost a few
megabytes. Each lab that needs it copies one init script (`init/kwok-nodes.sh`) wholesale, the same way
`certificate-renewal` reuses `issuers-and-trust`'s init.

What KWOK cannot fake, and which lab therefore needs a real kubelet:

| Needs a real kubelet | Why | Lab |
|---|---|---|
| Kubelet admission (`OutOfcpu`, `NoExecute` taints) | No kubelet, no admission. A fake node accepts anything bound to it | 1 |
| Graceful termination | A victim's grace period is the whole point of step 1 | 4 |
| Actual CPU usage | Nothing to measure | 8 |

### Must resolve before building anything on KWOK

This is the `cni-install-and-configure` of this folder: one spike unblocks four labs, so do it first.

- **DaemonSets land on fake nodes.** Cilium's DaemonSets tolerate every taint, so 30 fake nodes means
  60 fake Cilium Pods. That's harmless at 30 and possibly fatal at the 500 that `filter-and-score`
  step 4 wants. Decide whether the init patches a `kwok.x-k8s.io/node DoesNotExist` node affinity
  onto Cilium's DaemonSets, then confirm `cilium-operator` doesn't react badly to Nodes that never get
  a `CiliumNode`.
- **Keep real system Pods off fake nodes.** Taint every fake node `NoSchedule`. CoreDNS tolerates only
  the control-plane taint and `CriticalAddonsOnly`, so it stays put. Lab Pods carry the toleration.
  `TaintToleration` scores only `PreferNoSchedule` taints, so the toleration costs no score. That last
  claim is from the plugin's documented behaviour. Confirm it in the step 2 score logs.
- **Keep lab Pods off the real node.** The real node has images in `status.images` and fake nodes have
  none, so `ImageLocality` quietly favours the real node and distorts every score comparison. Pin lab
  workloads to fake nodes by label.
- **Measure the ceiling.** How many fake nodes the 1-node backend's API server and etcd will carry
  before `kubectl` slows down. Lab 2 step 4 wants about 500.
- **Fallback if any of the above goes badly:** `kwokctl create cluster --runtime binary` on the
  `ubuntu` backend. That's a whole fake cluster with its own apiserver and scheduler and no CNI at
  all. It loses the kubeadm static-Pod realism that lab 5 depends on, so it is a fallback, not the plan.

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
- **Per-plugin scores are logged at `V(10)`** as `"Plugin scored node for pod"` and
  `"Calculated node's final score for pod"` (`pkg/scheduler/schedule_one.go`).
- **Extender scores are scaled into the plugin range:** `score * weight * (MaxNodeScore / MaxExtenderPriority)`,
  so an extender's 0–10 lands on the same 0–100 scale as plugins.
- **An extender with empty `managedResources` receives every Pod**, and an ignorable extender that
  fails is skipped with an `Info`-level log line, with no event and no warning.
- **Node sampling never applies below 100 nodes** (`minFeasibleNodesToFind = 100`), and never drops
  below 5%.
- **`--kubeconfig` is ignored when `--config` is set**, along with `--kube-api-qps`, `--kube-api-burst`,
  `--kube-api-content-type`, `--profiling` and `--contention-profiling`.

## Build order

Chosen by what unblocks what, not by learning order.

1. ~~**`scheduler-by-hand`**~~ — **built**. Five steps on `kubernetes-kubeadm-2nodes`: three Pods
   that are `Pending` for three different reasons, a `Binding` POSTed by hand, a sixteen-line bash
   scheduler, three rules skipped and three different enforcers, and a runaway of `Failed` Pods with no
   back-off.
2. **The KWOK spike** above. Labs 2, 3, 6 and 7 are blocked until it lands.
3. **[`scheduler-profiles`](scheduler-profiles/)**: its main finding is documented rather than
   inferred, and it leaves behind a scheduler started with `--config`. Labs 2, 6 and 7 each need that
   in their init.
4. **[`filter-and-score`](filter-and-score/)**, then **[`topology-spread`](topology-spread/)**: the
   two most useful labs for daily work, once fake nodes exist.
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
