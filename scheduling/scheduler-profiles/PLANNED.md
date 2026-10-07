# One Flag, Two Failures: Configuring the Scheduler

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **Topic** | `KubeSchedulerConfiguration`: moving a kubeadm scheduler to `--config`, profiles, plugin args |
| **CKA relevance** | Cluster Architecture: static Pod manifests, and configuring control-plane components |
| **Proposed backend** | `kubernetes-kubeadm-1node` + KWOK for step 2's placement contrast (steps 1, 3, 4 run without it) |
| **Feasibility** | Ready. Step 2's fake nodes come from [`../kwok-nodes.sh`](../kwok-nodes.sh) (spike done). One error message to capture |

## What it teaches

Every scheduler customisation starts in the same file, and this lab is the cheapest kind: no code, no
new component. It covers one scheduler process with several *profiles*, each a named set of plugins
and plugin arguments, chosen per Pod by `schedulerName`. Getting a kubeadm scheduler to read that file
at all is the first lesson, because it fails twice in ways that point elsewhere.

## The finding at its heart

**Adding `--config` silently disables the `--kubeconfig` flag on the line above it.** The flag
reference says so: `--kubeconfig` *"is ignored if a config file is specified in --config"*, along with
`--kube-api-qps`, `--kube-api-burst` and `--profiling`. The kubeadm manifest still shows the flag,
pointing at a file that is still mounted. But the scheduler now takes its connection details from
`clientConnection.kubeconfig` in the config file. Left empty, that falls back to in-cluster config,
which a static Pod with no service account cannot use.

And before that failure there's a first one: the config file is on the host, the manifest names it, and
the container can't see it, because a static Pod gets only the `hostPath` mounts it declares.

## Step outline

1. **Two failures, both "the file is right there".** Add `--config=/etc/kubernetes/scheduler-config.yaml`
   to the static Pod with a minimal config. First failure: no such file, because there's no `hostPath`
   mount. Add the mount. Second failure: an in-cluster config error that never mentions kubeconfig.
   Set `clientConnection.kubeconfig: /etc/kubernetes/scheduler.conf`. Meanwhile every new Pod is
   `Pending` with no events, the [`scheduler-by-hand`](../scheduler-by-hand/) step 1 symptom again.
   Gate: the scheduler is `Running` under `--config` and a test Pod schedules.
2. **A second profile.** Add `bin-packing` alongside `default-scheduler`: `NodeResourcesFit` with
   `scoringStrategy: MostAllocated`. Deploy twelve Pods under each `schedulerName` onto fake nodes and
   compare how many nodes each set uses. Explain why `NodeResourcesBalancedAllocation` partly argues
   against the new strategy, and whether to turn its weight down.
3. **Cluster-wide defaults you never wrote.** Make the system default spreading visible and replace it:
   `PodTopologySpread` args with `defaultingType: List` and an explicit zone constraint. Then set
   `percentageOfNodesToScore: 100`, the fix that [`filter-and-score`](../filter-and-score/) step 4
   named. Gate on both fields in the running config, read back from the scheduler's own startup log
   rather than from the file.
4. **One process, one queue.** Try to give `bin-packing` its own `queueSort` plugin. The scheduler
   refuses to start, because all profiles share one queue. Then make a deliberate typo in a plugin
   argument and see what the scheduler does with an unknown field. Write down, in `/root/answers`, what
   profiles do *not* isolate.

## Must resolve before building

- **The exact error for the second failure.** The expectation is an in-cluster config error, probably
  about missing `KUBERNETES_SERVICE_HOST` or a missing service account token. Which one depends on
  which environment variables the kubelet injects into static Pods. Capture the real message. The step
  is built around the learner having to reason from it back to the flag.
- **What the scheduler does with an unknown config field.** Strict decoding would refuse to start, and
  lenient decoding would silently keep the default. Each makes a good step 4, but they are different
  steps. Find out which applies at the pinned version before writing it.
- **Whether the scheduler logs its effective configuration at startup**, and at what verbosity. Step 3's
  check reads it. If it isn't logged, gate on behaviour instead.
- The startup error for mismatched `queueSort` plugins, quoted verbatim.

## Cross-links

- [`troubleshooting/control-plane`](../../troubleshooting/control-plane/) step 1 broke this same
  manifest with a bogus flag. This lab breaks it with a real one.
- Every lab after this one in the folder assumes a scheduler running under `--config`, and copies this
  lab's final manifest and config into its init.
- [`scheduler-extender`](../scheduler-extender/) adds the top-level `extenders:` field to this same
  file.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted. See the conventions in `ckne/README.md`.
