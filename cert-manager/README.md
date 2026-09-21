# cert-manager

Certificate management as the subject, not as scenery.

[`ckne/gateway-tls`](../ckne/gateway-tls/) already uses cert-manager, but it hands the learner a
working `ClusterIssuer` and never opens it: the only objects written there are `Certificate`s, and
the only field that matters is `secretName`. That lab owns the *consumer* side — a Gateway listener
referencing a Secret — and it covers the CKNE objective for it.

**These labs are the layer underneath.** Where does an issuer live, whose Secret does it read, what
does the failure look like when it reads the wrong one, what does a renewal actually change, and
which of your workloads will notice.

## Status

Nothing here is built yet. Each directory holds a single `PLANNED.md` design spec and deliberately
no `index.json` — Killercoda only indexes directories that have one, so nothing here can be published
by accident.

| Spec | Feasibility | Finding |
|---|---|---|
| [`issuers-and-trust`](issuers-and-trust/) | **Ready** | cert-manager fails silently at apply time; the reason is on an object you were never told about |
| [`certificate-renewal`](certificate-renewal/) | Ready, one claim to version-check | The new certificate is on disk and the old one is on the wire |
| [`acme-http01`](acme-http01/) | **Verify first** — needs Pebble | An HTTP01 failure is an HTTP routing failure |

Two related specs live elsewhere, because they are about their folder's subject rather than about
certificates:

- [`ckne/04-security-and-policy/mtls-without-a-mesh`](../ckne/04-security-and-policy/mtls-without-a-mesh/)
  — workload identity with no sidecar, and a refusal with no status code.
- [`cluster-admin/webhook-certificate-expiry`](../cluster-admin/webhook-certificate-expiry/) — the
  same expiry, with the blast radius turned up to the whole API.

## Build order

1. **[`issuers-and-trust`](issuers-and-trust/)** — no new components, deterministic failures, and the
   prerequisite for everything else here. Nobody debugs an ACME `Order` without first having met a
   `CertificateRequest`.
2. **[`certificate-renewal`](certificate-renewal/)** — reuses that lab's init wholesale, and lands the
   best finding of the set.
3. Then whichever of the remaining three has the most value at the time. `acme-http01` is the most
   useful and the heaviest; `mtls-without-a-mesh` is the only one that touches a CKNE objective.

Real ACME is impossible here — no public DNS, nothing reachable from outside, and a live CA that
would rate-limit a lab into the ground. `acme-http01` runs against **Pebble** instead: same protocol,
disposable trust anchor. That is the one piece of these specs that has not been proven on the
backend yet.

## Conventions

Same as everywhere else in this repo — see [`ckne/README.md`](../ckne/README.md) for the two that
bite hardest:

- **Scenarios index exactly two levels deep.** A finished lab is `cert-manager/<scenario>/index.json`
  and nothing deeper.
- **Every check must say what it wanted.** Killercoda shows the learner a red cross and nothing else,
  so each `verify.sh` writes its reason to `/root/.check` and each init installs the `why` helper that
  prints it.
