# A Policy With Nothing to Enforce It

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Network Security & Policy (25%) |
| **Exam objective** | Implementing Pod-level Authentication and Authorization |
| **Mapped tech** | Istio (AuthorizationPolicy / PeerAuthentication) |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | **Blocked** — needs a sidecar or ambient data plane, which is the case the socket-LB constraint in `ckne/README.md` genuinely blocks |

## What it teaches

The Istio half of an objective whose Cilium half is
[`pod-identity-and-l7`](../../pod-identity-and-l7/). Authorization by workload identity rather
than by address, and the several ways an `AuthorizationPolicy` can be accepted while enforcing
nothing at all.

## The finding at its heart

In ambient mode, ztunnel does L4 mTLS only. An `AuthorizationPolicy` with L7 rules — methods,
paths — and no waypoint deployed is accepted, reports no error, and does nothing. Deploy the
waypoint and the identical policy starts refusing requests.

Same lesson as `pod-identity-and-l7`'s broad-L4-allow trap, reached from the opposite direction:
there the policy was defeated by another policy, here by the absence of anything able to read
the request.

## Step outline

1. **Deny by default, which is not the default.** With no policy, everything is allowed. Apply
   the first `ALLOW` policy and discover it did not merely add a permission — it made everything
   else denied for the workloads it selects. The blast radius of the first policy is the point.
2. **Identity, not address.** Allow by `principals` (the SPIFFE identity from the ServiceAccount)
   and prove that a Pod with the right labels and the wrong ServiceAccount is refused — the
   inverse of the `ipBlock` trap in `pod-identity-and-l7`.
3. **The policy that enforces nothing.** L7 rules with no waypoint: accepted, `kubectl get` clean,
   zero effect. Find the one place that says so, then deploy the waypoint and re-run unchanged.
4. **`ALLOW`, `DENY` and the order they are evaluated in.** `DENY` is checked first and wins, so
   a narrow `DENY` beats a broad `ALLOW` — which is the opposite of the additive-union model
   Kubernetes NetworkPolicy and CiliumNetworkPolicy both use. The two mental models are
   incompatible and the learner will be carrying the wrong one.

## Must resolve before building

- **The prerequisite in `ckne/README.md`** — see
  [`istio-peer-authentication`](../istio-peer-authentication/). Same blocker.
- **Ambient or sidecar**, decided once across the Istio labs. Step 3 is specifically an ambient
  finding; in sidecar mode the equivalent trap is different (the sidecar is always there, so the
  policy always enforces) and the step would have to be rewritten or dropped.
- Whether a waypoint is schedulable alongside istiod and the workloads on one node.

## Cross-links

- Companion to [`pod-identity-and-l7`](../../pod-identity-and-l7/) — same objective, other
  technology. Step 4's evaluation-order contrast is the seam and should reference it explicitly.
- Assumes [`istio-peer-authentication`](../istio-peer-authentication/) for identity; build that
  one first.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted — see the conventions in `ckne/README.md`.
