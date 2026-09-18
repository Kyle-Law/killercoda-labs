# PERMISSIVE Means Optional

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Network Security & Policy (25%) |
| **Exam objective** | Implementing Node and Pod Level Encryption |
| **Mapped tech** | Istio (mTLS via Envoy sidecars) |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | **Blocked** — needs a sidecar or ambient data plane, which is the case the socket-LB constraint in `ckne/README.md` genuinely blocks |

## What it teaches

The Istio half of an objective whose Cilium half is [`transparent-encryption`](../transparent-encryption/).
The two encrypt at different layers for different reasons and fail in different ways, and a
learner who has only seen one will generalise wrongly from it.

The belief this lab exists to break: *the mesh is installed, therefore traffic is authenticated
and encrypted.* `PeerAuthentication` defaults to `PERMISSIVE`, which means mTLS **if the client
offers it** — so an unmeshed caller keeps working, in plaintext, and every dashboard says the
mesh is healthy.

## The finding at its heart

Identity here is a certificate, not a label. That is a genuinely different model from the
label-derived security identity in [`pod-identity-and-l7`](../../pod-identity-and-l7/), and the
difference decides what each can and cannot enforce.

## Step outline

1. **Confirm mTLS is real between two meshed workloads.** Read the workload certificate out of
   the proxy and find the SPIFFE ID in it — `spiffe://<trust-domain>/ns/<ns>/sa/<sa>`. The
   identity is the ServiceAccount, which is the fact the rest of the lab turns on.
2. **Break the belief.** Call the same service from a Pod with no sidecar. It succeeds, in
   plaintext, against a mesh that reports itself fully healthy. Find the one place that admits it.
3. **`STRICT`, and its scope.** Apply it, watch the unmeshed caller fail, then find out what
   `STRICT` in one namespace does and does not cover — and what the root namespace does instead.
4. **Compare with the other half of the objective.** Cilium's WireGuard encrypts node-to-node
   and authenticates nothing at the workload level; Istio authenticates a workload identity and
   encrypts the connection. Neither is a superset. Which failure each one leaves you exposed to.

## Must resolve before building

- **The prerequisite in `ckne/README.md`:** this backend runs Cilium with
  `kubeProxyReplacement=true` and socket LB in pod namespaces, which Cilium's own documentation
  says disrupts Istio. `socketLB.hostNamespaceOnly: true` and `cni.exclusive: false` are
  required. Until that spike is done, this lab cannot be built — and the same applies to
  [`istio-authorization-policy`](../istio-authorization-policy/) and
  [`tracing-with-jaeger`](../../05-observability/tracing-with-jaeger/).
- **Sidecar or ambient**, decided once for all the Istio labs. Ambient is lighter per Pod and is
  where Istio is heading; sidecar makes step 1's certificate easier to read. Step 2's unmeshed
  caller works in either.
- Whether istiod plus a data plane fits on a 1-node backend alongside the workloads.

## Cross-links

- Companion to [`transparent-encryption`](../transparent-encryption/) — same objective, other
  technology. Step 4 is the seam; neither lab should claim to cover the objective alone.
- Contrast with [`pod-identity-and-l7`](../../pod-identity-and-l7/): certificate identity versus
  label-derived identity, for the same job.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted — see the conventions in `ckne/README.md`.
