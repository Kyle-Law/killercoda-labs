
A service that used to live at `legacy-api.example.com` now runs in this cluster as the `web` Service. Clients still ask for the old name and you cannot change them.

Make `legacy-api.example.com` resolve to `web` — without adding a Service, touching the application, or owning `example.com`.

Then settle an argument. Put the new plugin **last in the block, after `forward`**, and predict whether it will work before you apply it.

<br>

<details><summary>Tip</summary>

The plugin is `rewrite`, and the simplest form takes an exact name and the name to substitute:

```plain
rewrite name <from> <to>
```

Add it inside the `.:53` block. Deliberately put it at the very bottom, below `forward`, `cache` and `loadbalance`.

Reasoning it through: `forward` sends unmatched queries upstream. If plugins ran in file order, a rewrite placed after `forward` could never see the query.

</details>

<details><summary>Solution</summary>

```plain
sed -i '$ s/^}$/    rewrite name legacy-api.example.com web.default.svc.cluster.local\n}/' /root/Corefile
tail -6 /root/Corefile
applycorefile
```{{exec}}

> ```
>     loop
>     reload
>     loadbalance
>     rewrite name legacy-api.example.com web.default.svc.cluster.local
> }
> ```

```plain
dnsq legacy-api.example.com
```{{exec}}

> ```
> legacy-api.example.com -> 10.96.191.127
> ```

**It works, from the bottom of the block, below `forward`.**

This is the single most useful thing to know about the Corefile: **the order plugins appear in a server block is not the order they execute in.** CoreDNS compiles a fixed chain order into the binary — `rewrite` sits near the front of it, `forward` near the back — and your file is read as a *set* of enabled plugins with their settings, not as a sequence of steps. Moving lines around in a block changes nothing.

Look at what the client actually receives:

```plain
kubectl exec dnstools -- dig legacy-api.example.com
```{{exec}}

> ```
> ;; QUESTION SECTION:
> ;legacy-api.example.com.        IN  A
>
> ;; ANSWER SECTION:
> legacy-api.example.com. 30  IN  A   10.96.191.127
> ```

The answer comes back under the name that was **asked**, not the name it was rewritten to. `rewrite` restores it on the way out, so the client has no idea any of this happened — which is exactly what you want when the client is something you can't change. And it is a real address, so it carries traffic:

```plain
kubectl exec dnstools -- /bin/sh -c 'wget -qO- -T5 http://legacy-api.example.com/hostname'
echo
```{{exec}}

> The `web` Pod's name. A hostname the cluster does not own, pointed at a Service, with four words of configuration.

<br>

<details><summary>Info: so does <em>anything</em> about order matter?</summary>

Yes — but between server blocks, not inside them. Move the `corp.internal:53` block from the top of the file to the bottom, below `.:53`:

```plain
awk 'NR<=5{blk=blk$0 ORS; next} {rest=rest$0 ORS} END{printf "%s%s", rest, blk}' /root/Corefile > /tmp/reordered
mv /tmp/reordered /root/Corefile
head -3 /root/Corefile; echo '...'; tail -6 /root/Corefile
applycorefile
```{{exec}}

```plain
dnsq db.corp.internal
dnsq web.default.svc.cluster.local
```{{exec}}

Still correct. `.:53` matches every name including `db.corp.internal`, and it is now listed first — but CoreDNS routes each query to the **most specific** matching zone, not the first one in the file. `corp.internal` beats `.` wherever it appears.

So the rule is: which block handles a query is decided by zone specificity, and what happens inside that block is decided by a compiled-in plugin order. Neither is decided by where you typed it.

</details>

</details>
