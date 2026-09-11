
Another silent hang. This time the packets really are dying on the router — you can prove that the same way you did in step 1.

But `iptables -L -n -v` is clean. So is `-t nat`. So is `-t mangle`, and `-t raw`.

The rule exists. Find it, write the table it lives in to `/root/answers/step3.txt`, and remove it.

<br>

<details><summary>Tip</summary>

Confirm first that the router really is where the packets stop, so you are not chasing the wrong box:

```plain
netlab rtr timeout 5 tcpdump -nn -i vr1 tcp -c 2 > /tmp/r.txt 2>&1 &
sleep 1
netlab cli curl -m 3 -sS -o /dev/null http://10.10.2.2:8080/small.txt
sleep 5
cat /tmp/r.txt
```{{exec}}

Then check all four `iptables` tables and satisfy yourself they are genuinely empty:

```plain
for t in filter nat mangle raw; do echo "--- $t"; netlab rtr iptables -t $t -L -n -v; done
```{{exec}}

`iptables` is not the only way to write a rule, and on a modern kernel it is not even the native one.

</details>

<details><summary>Solution</summary>

```plain
for t in filter nat mangle raw; do echo "--- $t"; netlab rtr iptables -t $t -L -n -v; done
```{{exec}}

> Four empty tables. Every chain `policy ACCEPT`, every counter `0`.

It would be reasonable, and wrong, to conclude the firewall is innocent.

```plain
netlab rtr nft list ruleset
```{{exec}}

> ```
> table inet lab {
>     chain block {
>         type filter hook forward priority filter; policy accept;
>         tcp dport 8080 drop
>     }
> }
> ```

There it is. **`iptables` and `nft` are two front-ends onto the same kernel subsystem**, `nf_tables`. A rule written through `nft` is enforced exactly like an `iptables` rule and is completely invisible to `iptables -L`, because `iptables` only lists the tables it created itself.

That is not an exotic situation. It is the normal one:

- **Kubernetes** — `kube-proxy` in `nftables` mode, and Cilium's eBPF datapath, bypass the `iptables` view entirely
- **Docker** writes its own chains, and increasingly through `nft`
- **firewalld** and **libvirt** both manage rules you did not write
- Anything using the `iptables-nft` shim — which on most current distributions is what `/sbin/iptables` actually is

```plain
netlab rtr iptables --version
```{{exec}}

> `iptables v1.8.x (nf_tables)` — even the `iptables` command here is a translation layer over `nf_tables`. It simply declines to show you tables it does not own.

```plain
echo "nftables: table inet lab, chain block, tcp dport 8080 drop -- invisible to iptables -L" > /root/answers/step3.txt
netlab rtr nft delete table inet lab
netlab test
```{{exec}}

**The habit worth keeping: never conclude "it's not the firewall" from `iptables -L` alone.** Check `nft list ruleset` too — it shows everything, including the tables `iptables` created.

</details>
