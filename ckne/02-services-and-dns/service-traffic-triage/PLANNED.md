# It Reaches the Service and Not the Pod

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Service Networking & DNS (25%) |
| **Exam objective** | Troubleshooting Service Network Traffic |
| **Mapped tech** | Hubble + Cilium |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | Ready |

## What it teaches

Four ways a Service stops carrying traffic that all present to the caller as the same thing — a
connection that hangs or refuses — and are told apart by where in the flow log the traffic stops:
a selector matching nothing, a `targetPort` naming a port the container does not listen on, a
backend that is Ready to Kubernetes and not to the application, and traffic that reaches the Pod
and is refused by policy.

## The finding at its heart

`kubectl get svc` reports a healthy Service in all four cases. The EndpointSlice tells you about
two of them. Only the flow log distinguishes the last two, because the difference lives in what
happened *after* the packet arrived.

## Step outline

1. **No endpoints at all.** The selector matches nothing. Establish the fastest check —
   EndpointSlice, not Service — and what the flow log shows when there is nowhere to send traffic.
2. **Endpoints exist and the port is wrong.** `targetPort` naming a closed port: the flow reaches
   the Pod and is refused. Distinguish that from step 1 in the log rather than from the manifest.
3. **Ready is not the same as working.** A backend whose readiness probe passes while the
   application is failing. The endpoint is in the slice, the flow is forwarded, and the response
   is an error — which is the one case no amount of network-level debugging will explain.
4. **Refused by policy, at the Service address.** Policy enforced on the backend after the
   Service translation has already happened — so the drop names the *Pod*, and the Service the
   caller used appears nowhere in the verdict.

## Must resolve before building

- **Overlap with `troubleshooting/services-dns`**, which already covers a selector mismatch and a
  wrong `targetPort` with plain `kubectl`. This lab has to be the Hubble version — same faults,
  found from the flow log — or it should drop steps 1 and 2 and go deeper into 3 and 4. Decide
  before building, and cross-link either way.
- Whether step 4's verdict really does name the Pod rather than the Service on this datapath.
  Socket LB translates before a packet exists, so it almost certainly does — but that is the
  assumption this lab rests on and it has to be checked first.

## Cross-links

- Pairs with [`endpoint-availability`](../endpoint-availability/): that lab creates the broken
  endpoint conditions, this one finds them from outside.
- Uses the `flows` helper from [`flow-logs-and-drops`](../../flow-logs-and-drops/).
- `troubleshooting/services-dns` is the `kubectl`-only version — see above.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted — see the conventions in `ckne/README.md`.
