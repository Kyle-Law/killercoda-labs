# A Certificate Authority With No Internet

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **Topic** | Certificate management — ACME issuance and the HTTP01 challenge |
| **CKNE relevance** | Adjacent on paper, central in practice: an HTTP01 failure is an HTTP *routing* failure, which is squarely this repo's territory. |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | **Verify first** — needs Pebble, and several beats below depend on what Pebble actually enforces |

## What it teaches

Let's Encrypt is how most people meet cert-manager, and it cannot be taught on Killercoda: no public
DNS, nothing reachable from outside, and a real CA that would rate-limit a lab into the ground.

**Pebble** — the ACME protocol's own test server — makes the whole thing local. The protocol is
identical; only the trust anchor is disposable.

## The finding at its heart

**An HTTP01 challenge is a routing problem wearing a certificate costume.**

The solver creates a temporary Pod, Service and ingress route serving one path,
`/.well-known/acme-challenge/<token>`. If the cluster's existing routing does not admit that path —
wrong ingress class, a catch-all route that swallows it, a listener that is TLS-only — the
`Challenge` sits `pending` forever and the `Certificate` never appears.

The learner goes looking for a certificate problem. There is no certificate problem. There is a
request that never reached the solver Pod, and the way to see it is `curl` against the challenge URL.

## Step outline

1. **Point cert-manager at a CA that does not exist on the internet.** An ACME `Issuer` against
   Pebble, including the piece that trips everyone building this locally: cert-manager must be told
   to trust the ACME server's own certificate before it will talk to it at all. First order issues.
2. **Break the routing, not the certificate.** Change one thing about how the challenge path is
   routed and watch the order stall. Walk the chain — `Certificate → CertificateRequest → Order →
   Challenge` — to the `Challenge` object, read what the validation attempt reports, then reproduce
   the same failure by hand with one `curl`. Repair the route; the order completes with nothing
   touched in cert-manager.
3. **Ask for a wildcard, and be refused.** `*.example.com` over HTTP01 fails structurally, not
   incidentally: HTTP01 proves control of *one name over one URL*, and a wildcard has no URL. The
   error is worth reading in full. State what DNS01 does instead and why it needs credentials this
   lab cannot supply.
4. **What the staging issuer is for.** Reason from what step 1–3 cost in orders to why a real CA
   throttles, and why a production `ClusterIssuer` is always shadowed by a staging one.

## Must resolve before building

- **Which Pebble image and registry, and whether it can be pre-pulled** on the backend the way the
  built labs pre-pull with `ctr`/`crictl`. Everything below is moot if it cannot be cached.
- **How Pebble resolves the challenge hostname back to the cluster's ingress.** Pebble performs a
  real HTTP validation against the name being requested, so it needs a resolver that answers for it.
  [`ckne/coredns-customization`](../../ckne/coredns-customization/) proves the `hosts` and `rewrite`
  machinery for exactly this, so the mechanism exists — confirm Pebble can be pointed at CoreDNS, and
  which port it validates on.
- **Whether step 4 survives contact with Pebble at all.** Pebble is a protocol test server and may not
  enforce Let's Encrypt-style rate limits. If it does not, step 4 cannot be *demonstrated* — either
  cut it to a closing paragraph in `finish.md` or find a limit Pebble does enforce. Do not write a
  step around a limit that never fires.
- Which ingress or Gateway implementation carries the challenge route. Envoy Gateway is already used
  by two built labs, but the HTTP01 solver's ingress integration is written around `Ingress` — check
  whether the Gateway API solver path is usable at the pinned version, or use a plain ingress
  controller and keep the lab about ACME.

## Cross-links

- Assumes the object chain taught by [`issuers-and-trust`](../issuers-and-trust/). Build that first.
- Step 2's failure is an [`ckne/httproute-in-depth`](../../ckne/httproute-in-depth/) match-precedence
  problem in disguise — cross-link it.
- The DNS side of step 3 leans on [`ckne/coredns-customization`](../../ckne/coredns-customization/).

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted — see the conventions in `ckne/README.md`.
