
<br>

**A `Secret` of type `kubernetes.io/tls` is the entire contract between `cert-manager` and a `Gateway`.** `cert-manager` doesn't know Envoy exists, and the `Gateway` doesn't know `cert-manager` exists — a `Certificate`'s `secretName` and a listener's `certificateRefs` just have to name the same object. Anything else that wrote a valid keypair into a Secret of that shape would work exactly the same way from the listener's side.

**A hostname travels in the clear, once, before any certificate is exchanged — SNI is what makes multi-cert listeners possible at all.** Two listeners can share the same IP and the same port, each with its own certificate, distinguished purely by `hostname`. The server has to know which certificate to offer before the handshake can begin encrypting anything, and that's only knowable if the client says which hostname it wants first.

**Renewal is a Secret getting new contents, and every consumer finds out for free.** `cert-manager` reissues whenever a `Certificate`'s backing Secret doesn't hold a matching, unexpired keypair — including a Secret that was simply deleted. Envoy Gateway watches the Secret a listener references, not a specific version of it, so the new certificate is live the moment it's written: no `Gateway` edit, no restart, nothing to remember to do.

**`Terminate` and `Passthrough` trade the same thing in opposite directions.** `Terminate` gives Envoy the private key and, with it, everything that depends on reading the decrypted request — `HTTPRoute` path and header matching, the whole rest of this lab and the one before it. `Passthrough` keeps the key off the platform entirely, at the cost of losing all of that: a `Passthrough` listener's `supportedKinds` is `TLSRoute` and nothing else, because SNI — sent before encryption starts — is the only signal left to route on.

## Where to go next

- [`ckne/httproute-in-depth`](../httproute-in-depth/) — the plaintext version of this same Envoy Gateway setup: listener attachment, match precedence, weighted splitting
- [`ckne/coredns-customization`](../coredns-customization/) — the hostnames a TLS listener matches on by SNI still have to resolve to something, configured the same way regardless of what's listening on the far end
- [`netpol/allow-only-and-default-deny`](../../netpol/allow-only-and-default-deny/) — NetworkPolicy only ever sees L3/L4; a `Passthrough` listener makes that the literal truth for this traffic too, since nothing downstream of Envoy can read the request either

> `ckne/README.md` — this lab covers the CKNE "Managing TLS Certificates for Gateway API" objective in Network Security & Policy.
