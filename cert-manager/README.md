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

One lab built. The rest are `PLANNED.md` design specs with deliberately no `index.json` — Killercoda
only indexes directories that have one, so nothing unfinished here can be published by accident.

| Lab | Status | Finding |
|---|---|---|
| [`issuers-and-trust`](issuers-and-trust/) | **Built** | cert-manager fails silently at apply time; the reason is on an object you were never told about |
| [`certificate-renewal`](certificate-renewal/) | Planned — ready, one claim to version-check | The new certificate is on disk and the old one is on the wire |
| [`acme-http01`](acme-http01/) | Planned — **verify first**, needs Pebble | An HTTP01 failure is an HTTP routing failure |

### What building the first one settled

Two things the spec got wrong, both caught on a live cluster and both now load-bearing in the lab:

- **`ErrGetKeyPair` names no namespace at all.** The spec said a `ClusterIssuer` "fails naming a
  namespace the learner never wrote". It does not — it says `secrets "root-ca-tls" not found` and
  stops, while `kubectl get secret` in the namespace you created it in shows the Secret quite
  happily. The omission is what makes it confusing, so the lab is built around the omission.
- **Trusting the leaf works.** The spec assumed handing a client `tls.crt` would fail and so
  distinguish itself from `ca.crt`. OpenSSL anchors on the exact certificate presented, so `curl`
  succeeds and the mistake is invisible on the day it is made. Step 3's check therefore gates on
  `CA:TRUE` rather than on whether the request worked, and tells the learner their file verified and
  is still wrong.

Two related specs live elsewhere, because they are about their folder's subject rather than about
certificates:

- [`ckne/04-security-and-policy/mtls-without-a-mesh`](../ckne/04-security-and-policy/mtls-without-a-mesh/)
  — workload identity with no sidecar, and a refusal with no status code.
- [`cluster-admin/webhook-certificate-expiry`](../cluster-admin/webhook-certificate-expiry/) — the
  same expiry, with the blast radius turned up to the whole API.

## Build order

1. ~~**`issuers-and-trust`**~~ — **built**. Four steps on `kubernetes-kubeadm-1node`: a
   cross-namespace `issuerRef` that applies cleanly and never issues, a `ClusterIssuer` that cannot
   find a Secret you are looking straight at, `Ready: True` with `curl` exit 60, and a
   `trust-manager` `Bundle` that distributes the CA by label and refuses to carry the key.
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
