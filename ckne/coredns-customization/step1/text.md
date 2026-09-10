
Read the Corefile this cluster is running. For each of `kubernetes`, `forward` and `cache`, work out which lookups it is responsible for — then find a way to make CoreDNS *show* you rather than taking your word for it.

Turn on query logging, make two lookups that are handled by two different plugins, and find the field in the log line that distinguishes them.

<br>

<details><summary>Tip</summary>

```plain
corefile
```{{exec}}

`dnsq <name>` asks a question from inside the cluster and prints the answer, or the response code when there isn't one:

```plain
dnsq web.default.svc.cluster.local
dnsq db.corp.internal
```{{exec}}

The plugin you want is `log`, and it goes in the `.:53` block. Edit `/root/Corefile`, then apply it with `applycorefile` — that writes the ConfigMap and waits for CoreDNS to notice.

For the last part: look at the flags in the log line, not the response code. One lookup is answered by a plugin that *owns* the zone; the other is passed to somebody else.

</details>

<details><summary>Solution</summary>

```plain
corefile
```{{exec}}

> ```
> .:53 {
>     errors
>     health { lameduck 5s }
>     ready
>     kubernetes cluster.local in-addr.arpa ip6.arpa {
>        pods insecure
>        fallthrough in-addr.arpa ip6.arpa
>        ttl 30
>     }
>     prometheus :9153
>     forward . /etc/resolv.conf { max_concurrent 1000 }
>     cache 30 { ... }
>     loop
>     reload
>     loadbalance
> }
> ```

`.:53` is a **server block**: this block answers for the root zone, on port 53 — that is, everything. Inside it:

- **`kubernetes cluster.local in-addr.arpa ip6.arpa`** — the plugin that makes Services resolvable. It is authoritative for `cluster.local`, and it answers from the API server rather than from any zone file.
- **`forward . /etc/resolv.conf`** — anything the plugins above didn't answer goes to whatever the *node's* resolver is. This is the seam between cluster DNS and the outside world, and it's why a Pod can resolve `github.com` at all.
- **`cache 30`** — answers held for 30 seconds. This is also why a DNS change can appear not to have worked for half a minute.
- **`reload`** — watches the Corefile and applies changes without a restart. You are about to rely on it.
- **`errors`**, **`health`**, **`ready`**, **`loop`**, **`loadbalance`**, **`prometheus`** — logging of failures, the probe endpoints, a startup guard against forwarding loops, answer shuffling, and metrics.

Now stop reading and make it demonstrate itself:

```plain
sed -i 's/^    errors$/    errors\n    log/' /root/Corefile
head -5 /root/Corefile
applycorefile
```{{exec}}

> ```
> ConfigMap updated. Waiting for CoreDNS to reload......... done in 46s
> ```

That wait is the real behaviour and worth internalising: the ConfigMap update is instant, but the kubelet has to project the new file into the Pod and the `reload` plugin only checks periodically. **Expect roughly 30–90 seconds.** `kubectl -n kube-system rollout restart deployment/coredns` is immediate, but it restarts every CoreDNS Pod at once — fine here, a decision worth making deliberately in production.

Two lookups, two plugins:

```plain
dnsq web.default.svc.cluster.local
dnsq db.corp.internal
kubectl -n kube-system logs -l k8s-app=kube-dns --tail=20 | grep '"A IN'
```{{exec}}

> ```
> [INFO] 10.244.0.7:32900 - "A IN web.default.svc.cluster.local. udp 70 false 1232" NOERROR qr,aa,rd 92 0.00012075s
> [INFO] 10.244.0.7:50466 - "A IN db.corp.internal. udp 57 false 1232"            NXDOMAIN qr,rd,ra 34 0.003135708s
> ```

The distinguishing field is the flags, and specifically **`aa`**:

- `web.default.svc.cluster.local` comes back `NOERROR qr,**aa**,rd` — *authoritative answer*. The `kubernetes` plugin owns `cluster.local` and answered from its own knowledge.
- `db.corp.internal` comes back `NXDOMAIN qr,rd,**ra**` — no `aa`, but *recursion available*. Nothing in the block owns that name, so `forward` sent it upstream, and upstream said it doesn't exist.

That is the whole architecture in two log lines: one zone this cluster is authoritative for, everything else forwarded. The next step is about what to do when "everything else" is the wrong answer.

</details>
