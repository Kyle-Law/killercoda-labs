
<br>

### Recap

- `policyTypes: [Egress]` denies **every** outbound connection a Pod makes once selected, indiscriminately — DNS is not a special case Kubernetes protects for you. The failure doesn't announce itself as a policy problem: `wget: bad address` and `nslookup`'s connection timeout look exactly like a broken hostname or a DNS outage.
- A raw request to a ClusterIP, bypassing DNS entirely, is what separates "DNS is blocked" from "the connection itself is blocked" — the two often break together and produce different error text (`bad address` vs `download timed out`).
- Allowing DNS is **necessary, not sufficient**. Once resolution works again, the failure just changes shape — from an obvious DNS error to a plain connection timeout — which can look like progress without being a fix.
- Egress on the sender and ingress on the receiver are evaluated **independently, by separate policies**. Neither Pod's policy can grant permission on the other's behalf; "I opened egress, why is it still blocked" is usually a question about the *other* Pod's ingress rule.
- `namespaceSelector` and `podSelector` as fields of the **same** `to`/`from` list entry is an AND; as two separate entries it's an OR. Dropping the pod label from a "DNS-only" rule doesn't narrow it to CoreDNS — it opens every Pod in that namespace on that port, including the control plane.
- `nc`'s **refused vs. timed out** distinction is a real diagnostic technique: refused means the packet was let through and nothing was listening; timed out means something dropped it. Use it to tell "the policy allowed this" apart from "nothing was listening anyway."

### WELL DONE!

The most common NetworkPolicy outage, reproduced and fixed in full: a symptom that lies about its cause, a fix that's real but incomplete, a permission that only half-exists, and a rule that was quietly broader than intended the whole time.

Related lab in this set: `netpol/allow-only-and-default-deny` for the ingress side of this same model.
