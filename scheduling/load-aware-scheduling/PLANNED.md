# Scheduled on Requests, Running on Usage

> **Status:** planned — **verify first**. This file is the design spec, not a lab.

| | |
|---|---|
| **Topic** | Out-of-tree plugins: running `scheduler-plugins` as a second scheduler, with load-aware scoring (Trimaran) |
| **CKA relevance** | Adjacent. Resource requests and their effect on scheduling are in scope; usage-aware scoring is not |
| **Proposed backend** | `kubernetes-kubeadm-2nodes`: real kubelets, real CPU usage, metrics-server |
| **Feasibility** | Verify first: the heaviest lab here. Third-party image version skew, metrics-server on the backend, and an unknown step 3 outcome |

## What it teaches

Every lab before this one schedules on *requests*: numbers the Pod's author wrote, which the scheduler
believes. This lab shows what that costs. Then it reaches the third customisation surface: plugins
that aren't compiled into the default scheduler, from the
[`kubernetes-sigs/scheduler-plugins`](https://github.com/kubernetes-sigs/scheduler-plugins) prebuilt
image, run as a second scheduler beside the default one.

## The finding at its heart

**The scheduler places on requests, not usage. A node at 100% CPU looks empty.** Two Pods requesting
`10m` each and burning a full core apiece make `node01` the *least*-allocated node, because the
control plane's own Pods request far more. The default scheduler's `LeastAllocated` strategy therefore
sends the next Pod to the busiest machine. `kubectl top` and the scheduler are looking at different
numbers, and both are right.

## Step outline

1. **The hot node looks empty.** Start the CPU burners on `node01`, read `kubectl top node`, then deploy
   four ordinary Pods. Predict where they go before looking. Gate: the learner explains, in
   `/root/answers`, which number the scheduler compared.
2. **A second scheduler with a different idea of "full".** Install `scheduler-plugins` as a second
   scheduler with `TargetLoadPacking`, reading usage from metrics-server. Schedule the same four Pods
   with its `schedulerName`. They avoid the hot node. Read its config and explain
   `targetUtilization`: it packs *up to* a target rather than spreading.
3. **Usage is a lagging signal.** Submit ten Pods in one burst. Metrics refresh on a scrape interval,
   so either they pile onto whichever node looked coolest a moment ago, or Trimaran's prediction for
   newly bound Pods compensates. Observe which. Either way the step teaches the cost of scheduling on
   measured data.
4. **Choose.** Requests-based scheduling is predictable and wrong when requests lie. Usage-based
   scheduling is accurate and late. The real fix for step 1 is requests that tell the truth. Gate: the
   learner sets the burners' requests honestly and the *default* scheduler now avoids `node01`.

## Must resolve before building

- **A `scheduler-plugins` release whose `kube-scheduler` is within supported skew of the backend's
  API server.** scheduler-plugins releases follow upstream minors with a lag. If none is close enough,
  the lab is blocked until one is. Check this first. It's the cheapest way to find out the lab is
  impossible.
- **Whether Trimaran is still maintained and shipped in that image**, and whether its metrics-server
  provider still works without a separate `load-watcher` deployment.
- **metrics-server on the backend.** It likely needs `--kubelet-insecure-tls`. Confirm `kubectl top`
  works on both nodes before building anything on top of it.
- **Step 1's premise on this backend.** Confirm the control-plane node really has more CPU *requested*
  than `node01`, so `LeastAllocated` prefers `node01`. If the backend's DaemonSets balance the
  requests, add a request on the control plane rather than abandon the step.
- **Step 3's outcome is unknown by design.** Write it up after running it.

## Cross-links

- The burners' requests are the same kind of number as the extended resource in
  [`ai-workloads/gpu-scheduling`](../../ai-workloads/gpu-scheduling/), and just as unverified.
- [`descheduler`](../descheduler/)'s `LowNodeUtilization` can read usage instead of requests, the
  after-the-fact version of the same idea.
- The scheduler-plugins image also ships Coscheduling. The README notes why that belongs in
  [`gang-scheduling`](../../ai-workloads/gang-scheduling/) instead.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted. See the conventions in `ckne/README.md`.
