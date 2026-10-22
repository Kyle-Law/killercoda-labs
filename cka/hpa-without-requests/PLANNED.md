# The Autoscaler That Has Metrics and Won't Scale

> **Status:** planned, not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **Topic** | HorizontalPodAutoscaler: utilisation is a percentage *of a request* |
| **CKA domain** | Workloads & Scheduling (15%): configure workload autoscaling |
| **Proposed backend** | `kubernetes-kubeadm-1node`, with metrics-server installed in the init |
| **Feasibility** | Ready for steps 1 and 2 (observed below). Steps 3 and 4 have claims to resolve |

## What it teaches

`kubectl get hpa` shows `cpu: <unknown>/50%` and the instinct is to suspect metrics-server. It is the
wrong suspect. `kubectl top pods` works and shows the Pod burning CPU. The HPA cannot compute a
percentage because the percentage is *of the container's CPU request*, and there isn't one.

## The finding at its heart

**One container without a CPU request breaks the whole HPA, and the message names it.** A Deployment
with a correct request on its app container scaled 1 → 4 at `999%/50%`. Adding a sidecar with no request
turned the same HPA to `<unknown>`, with the condition naming the sidecar. Giving the sidecar a request
(`10m`) recovered it. A mutating webhook that injects a sidecar can switch off autoscaling for every
workload it touches, and nothing is `Failed`.

## Observed (kind, Kubernetes v1.37.0, metrics-server v0.9.0 with `--kubelet-insecure-tls`)

| State | `kubectl get hpa` | Condition |
|---|---|---|
| no CPU request | `cpu: <unknown>/50%`, 1 replica | `ScalingActive=False (FailedGetResourceMetric): … failed to get cpu utilization: missing request for cpu in container c of Pod norequests-…` |
| request `100m`, busy loop | `cpu: 999%/50%`, scaled to 4 | `ScalingActive=True (ValidMetricFound)`, `ScalingLimited=True (TooManyReplicas)` |
| + sidecar, no request | `cpu: <unknown>/50%`, stuck at 4 | `ScalingActive=False … missing request for cpu in container sidecar of Pod withrequests-…` |
| sidecar given `10m` | `cpu: 909%/50%` | recovered |

Metrics took about 75 to 90 seconds to appear after the HPA was created.

## Step outline

1. **`<unknown>`, with working metrics.** A Deployment burning CPU and an HPA reading `<unknown>`.
   Prove metrics-server is fine (`kubectl top`), find the condition, add the request. Gate: the HPA
   reports `ScalingActive=True` and the Deployment has more than one replica.
2. **The sidecar.** An HPA that was healthy stops reporting after a "platform change" (a second
   container, supplied as `/root/with-sidecar.yaml`). Find which container the message names and fix it.
   Gate: `ScalingActive=True` again. A second valid fix, a `ContainerResource` metric that targets only
   the app container, is worth a Tip. See *Must resolve*.
3. **Same `<unknown>`, different cause.** Break metrics-server instead (init leaves a second cluster
   state, or the step does it). `kubectl top` now fails and the HPA condition reads differently. The
   skill is telling the two apart from the condition, since the column looks identical.
4. **Why it will not scale down.** The HPA scaled up in seconds and sits at 4 replicas long after the
   load stops. Expected, not broken: a stabilisation window. Gate: change it to a lab timescale.

## Must resolve before building

- **The wording of the metrics-server-down condition** (step 3). Not captured: reproduce with the
  `--kubelet-insecure-tls` flag removed (a TLS error in the metrics-server log) and quote both the
  `kubectl top` error and the HPA condition.
- **The `ContainerResource` alternative** in step 2 on the backend's version. It is a documented metric
  type; the claim that it avoids the sidecar problem is not observed.
- **Step 4's default**: the scale-down stabilisation window is documented as 300 seconds. Measure it,
  and measure `behavior.scaleDown.stabilizationWindowSeconds: 30` before writing a check around it.
- **metrics-server on the Killercoda backend.** Whether it is pre-installed, and whether its image
  pulls. If not, the init installs it and needs `--kubelet-insecure-tls`; installing took about a minute
  here and needed the registry reachable.
- **`kubectl autoscale` flag name.** `--cpu-percent=50` worked on kubectl 1.32; `--cpu` did not. Newer
  kubectl uses `--cpu`. The lab should use the manifest form, or state which flag its backend takes.
- A CPU burner that is steady on a small VM: the busy loop here pinned a core.

## Cross-links

- [`probes/readiness-and-safe-rollouts`](../../probes/readiness-and-safe-rollouts/): the other
  case where a field's absence silently changes a controller's behaviour.
- [`scheduling/scheduler-by-hand`](../../scheduling/scheduler-by-hand/) step 5: requests are what
  every placement decision is made against, and what an oversized one does.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted. See the conventions in `ckne/README.md`.
