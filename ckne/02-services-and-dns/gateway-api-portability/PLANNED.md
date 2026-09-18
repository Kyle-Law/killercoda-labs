# The Spec Is Portable, the Policy Never Is

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Service Networking & DNS (25%) |
| **Exam objective** | Managing Traffic with the Gateway API |
| **Mapped tech** | Gateway API + Istio + Envoy + Cilium (all implement Gateway/HTTPRoute) |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | **Verify first** — two controllers on one node, and the Cilium/Istio interaction below |

## What it teaches

The curriculum lists four implementations for this sub-topic, and that is the lesson.
[`httproute-in-depth`](../../httproute-in-depth/) teaches Gateway API against one controller;
this teaches what happens when you move.

The same `Gateway` and `HTTPRoute` run unchanged on a second controller — genuine portability,
and worth seeing. Then everything *around* them turns out not to move at all, because every
capability the core spec does not cover lives in a vendor extension: Envoy Gateway wants a
`BackendTrafficPolicy`, Istio wants a `DestinationRule`, Cilium wants something else again. None
of them are Gateway API.

## The finding at its heart

`GatewayClass` is the seam. Above it the objects are identical; below it nothing is. A migration
that looks like a one-line change is a one-line change plus every policy you attached.

## Step outline

1. **Run the same route on two controllers.** One `HTTPRoute`, two `GatewayClass`es, two
   `Gateway`s. Prove both serve it — this half really is portable.
2. **Attach a policy and watch it not move.** Something the core spec cannot express — a load
   balancing algorithm, a retry, an outlier ejection. Write it for controller A, move the route to
   controller B, and find that the policy is simply not attached to anything any more, silently.
3. **Read the status, which is the only place it says so.** The policy's own `status.ancestors`
   names what it did and did not attach to. Nothing else reports the loss.
4. **What does move.** The conformance profiles: which parts of the spec each implementation
   claims, and how to check a capability before depending on it rather than after.

## Must resolve before building

- **Which two controllers.** Envoy Gateway is already used by two built labs; Cilium is already
  installed and has a Gateway API implementation, which would make it the cheapest second
  controller and avoids installing anything. Istio is the curriculum's third and is **not** ruled
  out: gateway-only Istio is unaffected by the socket-LB constraint in `ckne/README.md`, and
  [`inference-gateway`](../../03-traffic-management/inference-gateway/) runs it on this backend
  already — including the `networking.istio.io/service-type: NodePort` annotation that gets a
  Gateway to `Programmed=True` here.
- Whether two Gateway API controllers coexist cleanly on one node, given both want to own the
  CRDs. Envoy Gateway's chart installs its own copy — that conflict is already documented in
  `llm-routing`'s init and would need solving again here, differently.
- Whether a second `GatewayClass` is even schedulable alongside the first on a 1-node backend.

## Cross-links

- Direct sequel to [`httproute-in-depth`](../../httproute-in-depth/) — that lab is one controller
  in depth, this is the seam between two. Should not repeat `sectionName` or match precedence.
- [`gateway-tls`](../../gateway-tls/) has the same portability question for TLS config.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted — see the conventions in `ckne/README.md`.
