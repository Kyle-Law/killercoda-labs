# The Spans Arrive, and They Are Not Connected

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Observability (15%) |
| **Exam objective** | Troubleshooting E2E Network Performance with Tracing |
| **Mapped tech** | Jaeger + Istio/Envoy (trace generation) |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | **Verify first** — not on the mesh constraint, but on whether this needs a mesh at all (below) |

## What it teaches

The only sub-topic in the curriculum with no coverage anywhere in this repo.

A mesh generates spans for every hop without the application being changed, which is why tracing
is sold as free. The spans arrive in Jaeger. They are also, at first, **disconnected** — a pile
of single-hop traces rather than one request's journey — because the proxy can only continue a
trace whose context the application forwarded, and the application forwarded nothing.

## The finding at its heart

The mesh cannot propagate context it was never given. Envoy will happily create a span for every
hop and has no way to know that hop three belongs to the same request as hop one, unless the
application copied a header it does not know exists.

That is the one thing about distributed tracing that a diagram never conveys and a broken trace
teaches in a minute.

## Step outline

1. **Get spans for free.** Three services calling each other, mesh installed, no application
   change. Open Jaeger and find the traces — real spans, real latency, per hop.
2. **Notice they do not join up.** A three-hop request appears as three unrelated single-span
   traces. Work out what is missing before being told.
3. **Forward the header.** Propagate `traceparent` through the middle service and watch the three
   traces become one with a real critical path. The change is small, in the application, and
   nothing else works without it.
4. **Read the latency, and find the hop that is not where you think.** Use the assembled trace to
   attribute time — including time spent in the proxy itself rather than the application, which
   is the number that tells you whether the mesh is the problem.

## Must resolve before building

- **Whether this needs a mesh at all — decide first, it changes everything else.** A *gateway-only*
  Istio or Envoy install is not affected by the socket-LB constraint in `ckne/README.md`, and
  [`inference-gateway`](../../03-traffic-management/inference-gateway/) proves gateway-only Istio
  runs on this backend. But a gateway emits spans for hops *it* handles, and steps 2 and 3 are
  about hops the application owns. If per-hop spans need sidecars, this lab inherits the mesh
  blocker; if the three services can be strung through one gateway, it does not.
- **Whether a mesh is needed at all.** Envoy Gateway also emits spans and is already installed by
  two built labs. A gateway-only version would lose the multi-hop story that steps 2 and 3
  depend on — the whole point is hops the application owns. Decide early; it changes the lab.
- **Jaeger's footprint** on a 1-node backend. All-in-one with in-memory storage should be small,
  but it is another component beside istiod and a data plane, and this is the third lab in a row
  competing for the same node.
- Which three-service application to use. It has to be one where adding header propagation is a
  small, readable change — that diff is step 3.

## Cross-links

- Completes Observability alongside [`flow-logs-and-drops`](../../flow-logs-and-drops/) (logs) and
  [`network-metrics-that-matter`](../network-metrics-that-matter/) (metrics). The three should
  cross-reference: same question, three instruments, different answers.
- [`latency-attribution`](../latency-attribution/) overlaps step 4 — decide which lab owns
  attribution and have the other defer to it.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted — see the conventions in `ckne/README.md`.
