
One more legacy name, and this one is not a Service and never will be: `nas.storage.internal` is a storage appliance at **10.99.0.60**, sitting on the network with no DNS server anywhere that knows about it.

`rewrite` cannot help — there is nothing in the cluster to rewrite it *to*. Forwarding cannot help either, because nothing upstream owns `storage.internal`.

Make CoreDNS answer for it directly, from the `.:53` block.

Then, **before you reach for the fix**, apply it and check what else still works.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

The plugin takes entries in the same shape as `/etc/hosts` — address first, then the name — and it answers from that list without asking anyone:

```plain
    hosts {
        10.99.0.60 nas.storage.internal
    }
```

Put it in the `.:53` block, `applycorefile`, and then check **more than the name you just added**.

</details>

<details><summary>Solution</summary>

```plain
python3 - <<'PY'
s = open('/root/Corefile').read()
s = s.replace("    kubernetes cluster.local",
              "    hosts {\n        10.99.0.60 nas.storage.internal\n    }\n    kubernetes cluster.local", 1)
open('/root/Corefile','w').write(s)
PY
applycorefile
```{{exec}}

```plain
dnsq nas.storage.internal
```{{exec}}

> `nas.storage.internal -> 10.99.0.60`

Done. Now check the rest of the cluster:

```plain
dnsq web.default.svc.cluster.local
dnsq legacy-api.example.com
dnsq kubernetes.default.svc.cluster.local
dnsq db.corp.internal
```{{exec}}

> ```
> web.default.svc.cluster.local        -> no answer (status: SERVFAIL)
> legacy-api.example.com               -> no answer (status: SERVFAIL)
> kubernetes.default.svc.cluster.local -> no answer (status: SERVFAIL)
> db.corp.internal                     -> 10.99.0.42
> ```

**Cluster DNS is gone.** Three lines, one name added, and every Service in the cluster stopped resolving — including the `kubernetes` Service itself.

Two things explain it, and the second is the one worth keeping.

**`hosts` is authoritative by default.** It does not mean "answer these names and pass the rest along". It means "this block answers", and a name that is not in the list gets a failure rather than a chance at the next plugin.

**And `hosts` runs before `kubernetes`.** Plugin order inside a block is compiled into CoreDNS, not read from your file — step 3 established that. In that fixed order `hosts` sits ahead of `kubernetes` and ahead of `forward`, so it sees *every* query in the block first, and nothing you added is anywhere near the Service lookups it just started intercepting.

Now look again at the one name that survived:

```plain
dnsq db.corp.internal
```{{exec}}

> `db.corp.internal -> 10.99.0.42`

**`corp.internal` still resolves, because it is handled by a different server block.** The blast radius of a plugin is the block it is written in — which is the argument for the separate `corp.internal:53` block you wrote in step 2, rather than bolting a `forward` onto `.:53`.

The fix is one word:

```plain
python3 - <<'PY'
s = open('/root/Corefile').read()
s = s.replace("        10.99.0.60 nas.storage.internal\n",
              "        10.99.0.60 nas.storage.internal\n        fallthrough\n", 1)
open('/root/Corefile','w').write(s)
PY
applycorefile
```{{exec}}

```plain
dnsq nas.storage.internal
dnsq web.default.svc.cluster.local
dnsq legacy-api.example.com
dnsq db.corp.internal
```{{exec}}

> All four answer correctly.

`fallthrough` turns "this block answers" into "this block answers the names it knows, and passes everything else on".

> **Two ways to make a name resolve, and they age differently.** Step 3 used `rewrite` to point `legacy-api.example.com` at a Service — the query is rewritten, so it follows that Service wherever its ClusterIP goes. Here `hosts` pins a literal address. That is right for the storage appliance, which has a fixed address and no Service, and wrong for anything Kubernetes manages: the day the address changes, DNS keeps confidently serving the old one. Pin addresses only for things that genuinely have one.

</details>
