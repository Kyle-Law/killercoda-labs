# Renewal That Nobody Reloaded

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **Topic** | Certificate management — lifecycle, rotation, and the consumer side |
| **CKNE relevance** | Adjacent, but the failure is a networking outage: a handshake that stops working while every object reads `Ready`. |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | Ready — no new components. One behavioural claim must be version-checked first (below). |

## What it teaches

[`ckne/gateway-tls`](../../ckne/gateway-tls/) step 3 proved a renewal the `Gateway` never had to be
told about: delete the Secret, cert-manager reissues, Envoy serves the new certificate with no
restart and no edit. That lab presents it as how renewal works.

**It is the exception.** Envoy Gateway watches the Secret a listener references. Almost nothing else
does.

## The finding at its heart

A Pod that mounts a `kubernetes.io/tls` Secret as a volume *does* receive the renewed files — after
the kubelet's sync interval, not immediately. But the server process inside read that certificate
into memory at startup and has no reason to look again. **The new certificate is on disk and the old
one is on the wire**, and it stays that way until something signals the process.

Every object is green. `kubectl get certificate` says `True`. The expiry that takes the service down
is the one nobody was watching, because the renewal succeeded.

## Step outline

1. **Make renewal happen on a lab timescale.** Set `duration` and `renewBefore` so a certificate
   renews while the learner watches, and find where cert-manager records what it will do and when.
   Meet the validation that *does* fire at apply time for once — `renewBefore` cannot be longer than
   the certificate's own lifetime — and note the contrast with the silent failures of
   [`issuers-and-trust`](../issuers-and-trust/).
2. **Watch the file change and the wire not.** nginx serving that Secret from a volume mount. Renew,
   wait out the kubelet sync, then compare two things: the serial in the file inside the container,
   and the serial `openssl s_client` gets back. They differ. Work out why before being told.
3. **Fix it, three ways, and rank them.** Signal the process, restart the Pod, or use a sidecar/
   reloader that watches the file. Each is a real answer with a different cost, and the point is that
   *the platform cannot pick for you* — cert-manager's contract ends at the Secret.
4. **The key that survived every renewal.** Compare the public key across a renewal. Whether a
   renewal issues a *new* private key or re-signs the existing one is one field,
   `privateKey.rotationPolicy` — and under one setting a compromised key stays compromised through
   every renewal for as long as the workload lives.

## Must resolve before building

- **The default value of `privateKey.rotationPolicy` at the pinned version.** This default changed in
  a recent cert-manager release, which means the behaviour depends on when a cluster was installed —
  that is a *better* finding than either value alone, but only if the version boundary is stated
  correctly. **Verify against the actual pinned chart before writing step 4**, and quote the observed
  behaviour, not the release note.
- The real propagation delay for a Secret volume update on this backend. The lab's timing depends on
  it, and "about a minute" is not good enough to write a check around — measure it.
- Whether the minimum `duration` cert-manager's webhook accepts is short enough for steps 1–2 to run
  inside a lab session, or whether renewal has to be forced rather than waited for.
- Which reloader to demonstrate in step 3, if any — a third-party component may be more than the step
  needs when a `SIGHUP` makes the same point.

## Cross-links

- Direct sequel to [`ckne/gateway-tls`](../../ckne/gateway-tls/) step 3, and should say so: this lab
  exists because that one showed the easy case.
- Reuses the issuer setup from [`issuers-and-trust`](../issuers-and-trust/).
- [`cluster-admin/webhook-certificate-expiry`](../../cluster-admin/webhook-certificate-expiry/) is the
  same expiry with the blast radius turned up.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted — see the conventions in `ckne/README.md`.
