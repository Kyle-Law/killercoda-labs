
<br>

**The Corefile is a set of server blocks, and each block is a set of plugins.** A block names the zone it answers for; the plugins inside it decide how. `kubernetes cluster.local` is the only reason a Service name resolves, and `forward . /etc/resolv.conf` is the seam between the cluster and everything else.

**Neither kind of order is the order you typed.** Which block handles a query is decided by zone specificity — `corp.internal` beats `.` wherever it sits in the file. What happens inside a block is decided by a plugin order compiled into the CoreDNS binary, which is why a `rewrite` written below `forward` still runs first. Rearranging lines to fix a DNS problem is time wasted.

**A stub domain is a server block, not a Pod-level setting.** Four lines join a cluster to a zone owned by someone else, once, for every workload — instead of `dnsConfig` repeated in every Deployment. Give the new block its own `cache`; plugins are per-block, so it inherits nothing from `.:53`.

**`rewrite` answers under the name that was asked.** The client sees the hostname it requested with an address behind it, and never learns a substitution happened — which is what makes it viable for clients you can't change.

**Config changes take 30–90 seconds and that is not a bug.** The ConfigMap write is instant; the kubelet has to project the file into the Pod and the `reload` plugin polls. `rollout restart` is the immediate alternative and restarts every replica at once.

**A broken Corefile does not take DNS down, and that is the dangerous part.** `reload` parses before swapping, so a typo is rejected and the last good config keeps serving. Meanwhile `kubectl apply` succeeded, the stored config is broken, every lookup works, and nothing alerts. The gap between the bad edit and the outage is however long until a Pod happens to restart — and once one replica is CrashLooping, DNS still answers from the other, so the warning sign is invisible too. **After any Corefile change, check that the reload succeeded and that every CoreDNS Pod is `Running` with no new restarts.**

**Turn on `log` when you need evidence, not opinions.** The flags say which plugin answered: `aa` means a plugin was authoritative for the zone, `ra` without `aa` means it was forwarded to somebody else.

## Where to go next

- [`troubleshooting/services-dns`](../../troubleshooting/services-dns/) — the other direction: cluster DNS when it is already broken and you have to find out why
- [`netpol/egress-and-the-dns-trap`](../../netpol/egress-and-the-dns-trap/) — DNS as a network flow, and the default-deny egress policy that silently blocks port 53
- [`networking/multi-port-services`](../../networking/multi-port-services/) — what a Service name resolves *to*, and how ports and endpoints hang off it
- [`ckne/README.md`](../README.md) — this lab covers the CKNE "Customizing CoreDNS for Services" objective in Service Networking & DNS

> Not covered here, and worth reading about before an exam: `hosts` for static entries, `template` for synthesising answers, `autopath` for cutting the search-domain round trips that `ndots:5` causes, and `k8s_external` for exposing Services under a domain you own.
