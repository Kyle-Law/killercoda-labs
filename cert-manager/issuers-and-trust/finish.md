
<br>

**cert-manager records failures on the object that failed, which is never the one you wrote.** A `Certificate` is a standing wish; a `CertificateRequest` is one attempt to grant it. The `Certificate` will tell you it is issuing, forever, in the same words whether it is thirty seconds from success or permanently broken — because from its point of view nothing has gone wrong, the Secret simply does not exist yet. `kubectl describe certificaterequest` is the first command, not the third.

**`issuerRef` has no namespace field, and that is a deliberate boundary rather than an omission.** A `Certificate` can name an `Issuer` in its own namespace or a `ClusterIssuer` in none, and there is no third option. Whoever can create a `Certificate` in a namespace can use every issuer that namespace can reach — so an issuer reachable from anywhere is a decision about who may ask for certificates signed by that CA, and making one cluster-scoped is the act of granting it.

**A `ClusterIssuer` reads every Secret it needs from one fixed namespace, and will not tell you which.** It has no namespace of its own to resolve `secretName` against, so cert-manager gives it `--cluster-resource-namespace`, defaulting to wherever cert-manager runs. `ErrGetKeyPair: secrets "root-ca-tls" not found` is true and useless in the same breath — the Secret is right there in the namespace you created it in, and cert-manager never looked. The same rule governs ACME account keys and cloud credentials, and `trust-manager` applies it to `Bundle` sources for the same reason.

**`Ready: True` is a statement about issuance, and says nothing about trust.** Step 2 ended with a valid certificate and step 3 began with `curl` exit 60, having changed nothing in between. Getting a certificate signed and getting a client to believe the signer are two separate pieces of work, and only the first one has a controller.

**A trust store built from leaf certificates works, right up until it doesn't.** Handing a client `tls.crt` makes the handshake succeed — OpenSSL will anchor on the exact certificate presented — so the mistake is invisible on the day it is made. It grants trust to one certificate with a 90-day life, instead of to the authority behind it, and it comes back as an outage at the first renewal. `ca.crt` is the file that gets distributed, and `CA:TRUE` is how you tell them apart.

**Distributing a CA is a control loop, not a copy.** A `trust-manager` `Bundle` writes into every namespace matching a label and keeps it there, so a new namespace opts in by being labelled rather than by someone remembering. It also cannot leak the thing that would matter: sourcing `tls.key` is refused outright — *only CERTIFICATE blocks are permitted* — because a trust bundle is public by construction and the one file that must never travel with it is the key.

## Where to go next

- [`ckne/gateway-tls`](../../ckne/gateway-tls/) — the consumer side of the Secret this lab produced: a Gateway listener referencing it, SNI across two certificates, and `Terminate` versus `Passthrough`
- [`cert-manager/certificate-renewal`](../certificate-renewal/) — what a renewal actually changes, and which of your workloads will never notice *(planned)*
- [`ckne/coredns-customization`](../../ckne/coredns-customization/) — the names a certificate is issued for still have to resolve, and SANs are matched against the name the client asked for

> See [`cert-manager/README.md`](../README.md) for how this lab relates to the rest of the set.
