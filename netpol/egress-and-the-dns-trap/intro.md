
<br>

`netpol/allow-only-and-default-deny` covered ingress: select a Pod, and it stops accepting traffic by default. Egress works exactly the same way, selecting the same Pod as a *source* instead of a *destination* — and that symmetry is exactly what makes it dangerous.

The moment a Pod is selected by a policy naming `Egress`, it stops being able to look anything up by name. DNS queries go through the network like any other connection, to a specific destination (CoreDNS, in `kube-system`) on a specific port (53) — and a default-deny egress policy blocks that connection exactly as thoroughly as it blocks everything else. The application never sees a policy error. It sees a hostname that suddenly won't resolve, which looks exactly like a typo, an outage in some other service, or a bug someone shipped an hour ago.

Two Pods are running in the `shop` namespace: `web`, which calls `api` by name over HTTP. Right now that works.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
