# Workload Identity Without a Sidecar

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Network Security & Policy (25%) |
| **Exam objective** | Partial cover for *Implementing Node and Pod Level Encryption* — see the honesty note below |
| **Mapped tech** | cert-manager (+ `cert-manager-csi-driver`), not the curriculum's Istio/Cilium |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | **Verify first** — the nginx half is straightforward; the CSI half is a new component |

## What it teaches

Mutual TLS between two workloads, where each proves who it is with a certificate and neither trusts
an IP address, a label, or a namespace to do it.

## Why this spec exists

`ckne/README.md` records [`istio-peer-authentication`](../istio-peer-authentication/) and
[`istio-authorization-policy`](../istio-authorization-policy/) as **blocked**: mTLS between workloads
needs sidecars or ambient, and both conflict with the backend's socket load balancing.

This reaches a real part of the same ground with no mesh at all — and in doing so teaches something
the mesh version actively hides, which is what the mesh was doing on your behalf.

> **Honesty note, to be carried into the lab text.** This does **not** replace the blocked specs and
> must not be described as covering their objective. The curriculum maps that objective to Cilium's
> IPsec/WireGuard and to Istio; this is neither. What it covers is the *identity* half — certificates
> as the thing being authenticated — while [`transparent-encryption`](../transparent-encryption/)
> still owns the node-level encryption half. Say so in `finish.md` rather than letting a learner
> believe the box is ticked.

## The finding at its heart

**Refusal happens at the TLS layer, where there is no status code to tell you about it.**

An unauthenticated client does not get a `403`. It gets a connection that dies inside the handshake —
a `curl` exit code and an `SSL alert`, with no HTTP response because HTTP never began. Every
troubleshooting instinct built on reading status codes is useless here, and that is the lesson:
`403` and a failed handshake are refusals from two different layers, and the tools that show you one
are blind to the other.

[`ckne/pod-identity-and-l7`](../../pod-identity-and-l7/) already teaches the `403`-versus-`000`
distinction from the policy side. This is the same boundary approached from the certificate side, and
the two labs should be read together.

## Step outline

1. **Server-side TLS, one CA, one name.** Issue a server certificate and serve it. Establish that the
   client trusting the CA is a separate act from the server holding a certificate — the ground
   [`cert-manager/issuers-and-trust`](../../../cert-manager/issuers-and-trust/) covers in depth.
2. **Turn the requirement around.** Configure the server to *require* a client certificate. The
   client that worked a moment ago now fails — and fails without an HTTP response. Read the exit code
   and the alert, and say which layer refused.
3. **Issue the client an identity and use it.** A client certificate from the same CA gets through.
   Then show where the identity actually lands: the server can read the client's subject and SANs and
   log it, so authorisation can be written against *who connected* rather than *which IP connected*.
   Contrast with an `ipBlock` — the trap
   [`ckne/pod-identity-and-l7`](../../pod-identity-and-l7/) already documents.
4. **Certificates that are never Secrets.** With `cert-manager-csi-driver`, a Pod gets a short-lived
   certificate written straight into its volume at start, rotated in place, and destroyed with the
   Pod. No Secret object, nothing to leak through RBAC, nothing left behind. A different trust model,
   and the nearest thing to SPIFFE that fits on one node.

## Must resolve before building

- **Whether step 4 is a step or a second lab.** `cert-manager-csi-driver` is a new DaemonSet and a new
  volume syntax, and steps 1–3 already make the lab's point. If it does not fit in one step, cut it
  and spec it separately rather than rushing it.
- The exact `curl` exit code and OpenSSL alert for step 2 on this backend — the check and the text
  should both quote what actually comes back, and this is precisely the kind of detail that differs
  by client version.
- Which server to use. nginx's client-verification directives are the clearest to read, but confirm
  the image available on the backend has what is needed and that its variables expose the client
  subject.
- Whether the socket-LB constraint touches any of this. It should not — there is no sidecar and no
  ambient proxy, and the traffic is ordinary Pod-to-Pod — but the whole reason this spec exists is
  that assumption failing elsewhere, so check it rather than assume it.

## Cross-links

- [`ckne/pod-identity-and-l7`](../../pod-identity-and-l7/) — the same layer boundary from the policy
  side.
- [`transparent-encryption`](../transparent-encryption/) — owns the encryption half of the objective
  this lab only partly touches.
- [`cert-manager/issuers-and-trust`](../../../cert-manager/issuers-and-trust/) — the CA and trust
  distribution this lab assumes.
- [`ckne/gateway-tls`](../../gateway-tls/) — server-side termination, one hop further out.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted — see the conventions in `ckne/README.md`.
