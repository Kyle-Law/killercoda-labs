# The Issuer Is Ready and Nothing Is Signed

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **Topic** | Certificate management — issuance and trust |
| **CKNE relevance** | Adjacent. The built [`ckne/gateway-tls`](../../ckne/gateway-tls/) owns the *Managing TLS Certificates for Gateway API* objective; this is the layer underneath it. |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | **Ready** — cert-manager v1.20.3 already installs cleanly on this backend, proven by `ckne/gateway-tls` |

## What it teaches

[`ckne/gateway-tls`](../../ckne/gateway-tls/) hands the learner a working `ClusterIssuer` and never
opens it. Everything that actually goes wrong with cert-manager in production goes wrong one layer
below that gift: in *which* issuer, in *which namespace*, reading *whose* Secret.

## The finding at its heart

**cert-manager fails silently at apply time.** Every broken configuration in this lab returns
`created` and then does nothing. There is no error to read, because the error has not happened yet —
it happens later, in a controller, and is recorded on an object the learner has not been told exists.

Knowing `kubectl describe certificaterequest` is the difference between a five-minute fix and an
afternoon.

## Step outline

1. **A reference that resolves to nothing.** Create an `Issuer` in one namespace and a `Certificate`
   in another that names it. Both apply cleanly. Nothing issues. Find out where the reason is
   written — and establish the chain `Certificate → CertificateRequest → (Order → Challenge)` as the
   route to every answer in this lab.
2. **The namespace you never typed.** Build a `ClusterIssuer` of type `ca`, putting its signing
   keypair in the application's namespace, where it obviously belongs. It fails naming a namespace
   the learner never wrote. `ClusterIssuer` secret references resolve against cert-manager's
   `--cluster-resource-namespace` — the install namespace — because a cluster-scoped object cannot
   have a namespace of its own to resolve against. Move the Secret; it signs.
3. **Ready is not trusted.** With a genuinely `Ready` certificate serving on a real listener, `curl`
   still refuses it. Issuance and trust are two separate problems and only one of them has been
   solved. Find the CA in `ca.crt` on the issued Secret and make the client accept it — the proof is
   a handshake that succeeds, not a field that reads `True`.
4. **Distributing that trust, once, to everywhere.** Step 3's fix does not scale: every namespace,
   every client, every image with its own trust store. Install `trust-manager` and use a `Bundle` to
   push the CA into ConfigMaps across namespaces, and note what it deliberately will not do — it
   distributes public certificates, never keys.

## Must resolve before building

- **Whether step 4 earns its place or should be cut.** `trust-manager` is a second component and a
  second CRD set for one beat. If it makes the lab five steps of setup and one of insight, fold the
  idea into step 3's closing text and leave the lab at three steps.
- The exact `Ready=False` reason strings and event text for steps 1 and 2 at the pinned cert-manager
  version — the lab text should quote what the learner will actually see, not a paraphrase.
- Whether to use Envoy Gateway for step 3's listener (reuses `ckne/gateway-tls`'s init wholesale) or a
  plain nginx Pod (far lighter, and this lab is not about gateways). Lean nginx.

## Cross-links

- Prerequisite in spirit for [`acme-http01`](../acme-http01/) — an ACME `Order` cannot be debugged by
  someone who has not met a `CertificateRequest`.
- [`certificate-renewal`](../certificate-renewal/) reuses this lab's issuer setup exactly.
- [`ckne/gateway-tls`](../../ckne/gateway-tls/) is the consumer side of the same Secret.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted — see the conventions in `ckne/README.md`.
