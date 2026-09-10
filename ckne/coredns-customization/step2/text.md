
`db.corp.internal` does not resolve, and the last step showed why: nothing in the cluster owns `corp.internal`, so the query is forwarded upstream, and upstream has never heard of it either.

There is a resolver in this cluster that *does* know the zone. Find it, confirm it has the answer, and then make cluster DNS use it — for that zone only, without changing what happens to anything else.

<br>

<details><summary>Tip</summary>

The resolver is the `corp-dns` Service in the `corp-dns` namespace. `dnsq` takes a second argument to bypass cluster DNS and ask a specific server directly:

```plain
kubectl -n corp-dns get svc corp-dns
dnsq db.corp.internal $(kubectl -n corp-dns get svc corp-dns -o jsonpath='{.spec.clusterIP}')
```{{exec}}

A Corefile can hold more than one server block, and each names the zone it answers for. You want a *second* block for `corp.internal` that forwards to that address — not a change to the existing `.:53` block.

</details>

<details><summary>Solution</summary>

First confirm the resolver actually has the answer, so that if this doesn't work you know which half to suspect:

```plain
CORP_IP=$(kubectl -n corp-dns get svc corp-dns -o jsonpath='{.spec.clusterIP}')
echo "corporate resolver: $CORP_IP"
dnsq db.corp.internal $CORP_IP
dnsq db.corp.internal
```{{exec}}

> ```
> db.corp.internal (asking 10.96.112.250 directly) -> 10.99.0.42
> db.corp.internal -> no answer (status: NXDOMAIN)
> ```

The answer exists. Cluster DNS just isn't asking the right server. Add a block that does:

```plain
CORP_IP=$(kubectl -n corp-dns get svc corp-dns -o jsonpath='{.spec.clusterIP}')
cat > /tmp/stub <<EOF
corp.internal:53 {
    errors
    cache 30
    forward . $CORP_IP
}
EOF
cat /tmp/stub /root/Corefile > /tmp/new && mv /tmp/new /root/Corefile
head -6 /root/Corefile
applycorefile
```{{exec}}

```plain
dnsq db.corp.internal
dnsq mail.corp.internal
dnsq web.default.svc.cluster.local
dnsq github.com
```{{exec}}

> ```
> db.corp.internal              -> 10.99.0.42
> mail.corp.internal            -> 10.99.0.43
> web.default.svc.cluster.local -> 10.96.191.127
> github.com                    -> 140.82.x.x
> ```

Both names in the corporate zone resolve, and nothing else changed. That is a **stub domain**, and it is how a cluster is joined to the DNS of the organisation around it — an internal CA, a legacy database, an Active Directory zone. The alternative people reach for first is editing every Pod's `dnsConfig`, which is the same change made once per workload instead of once per cluster.

Two details worth having:

- **`cache 30` in the new block is doing work.** Each server block gets its own plugin chain — the `cache` in `.:53` does not apply here. Leave it out and every lookup in the zone becomes a round trip to the other team's resolver.
- **The address is a ClusterIP, and ClusterIPs are stable but not permanent.** Delete and recreate that Service and this Corefile is silently wrong. In a real cluster the forward target is usually a fixed external address; when it must be an in-cluster Service, the Corefile becomes something to template rather than hand-edit.

</details>
