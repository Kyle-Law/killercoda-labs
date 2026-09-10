
One request, one connection, two ends. Capture both simultaneously and account for every address that changes between them — and every one that doesn't.

Save `client`'s side to `/root/cap-client-side.txt` and `web`'s side to `/root/cap-server-side.txt`.

<br>

<details><summary>Tip</summary>

Two `tcpdump`s backgrounded together, one per interface, before the request:

```plain
WVETH=$(cat /root/veth-web.txt)
CVETH=$(podveth client)
CLUSTERIP=$(kubectl get svc web -o jsonpath='{.spec.clusterIP}')
tcpdump -i $CVETH -n -c 10 tcp > /root/cap-client-side.txt 2>&1 &
tcpdump -i $WVETH -n -c 10 tcp > /root/cap-server-side.txt 2>&1 &
sleep 1
```{{exec}}

```plain
kubectl exec client -- wget -qO- -T5 http://$CLUSTERIP/hostname
echo
sleep 2
```{{exec}}

Compare the opening `SYN` line from each file — not just the addresses, everything on the line.

</details>

<details><summary>Solution</summary>

```plain
WVETH=$(cat /root/veth-web.txt)
CVETH=$(podveth client)
CLUSTERIP=$(kubectl get svc web -o jsonpath='{.spec.clusterIP}')
tcpdump -i $CVETH -n -c 10 tcp > /root/cap-client-side.txt 2>&1 &
tcpdump -i $WVETH -n -c 10 tcp > /root/cap-server-side.txt 2>&1 &
sleep 1
kubectl exec client -- wget -qO- -T5 http://$CLUSTERIP/hostname
echo
sleep 2
```{{exec}}

```plain
echo "--- client side ---"; grep 'Flags \[S\]' /root/cap-client-side.txt
echo "--- server side ---"; grep 'Flags \[S\]' /root/cap-server-side.txt
```{{exec}}

> ```
> --- client side ---
> 10.244.0.6.51866 > 10.96.244.124.80: Flags [S], seq 1254806050, ...
> --- server side ---
> 10.244.0.6.51866 > 10.244.0.5.8080: Flags [S], seq 1254806050, ...
> ```

Same source `10.244.0.6.51866`. Same `seq 1254806050` — proof, independent of anything `kubectl` says, that this is the *same* packet on both captures, one hop apart. And exactly one field differs: the destination, `10.96.244.124.80` became `10.244.0.5.8080`. That's every address translation this connection went through — there is only the one.

The source address is the detail worth sitting with. Go back to the `DNAT` rule from step 3:

```plain
cat /root/dnat-rule.txt
```{{exec}}

It rewrites the *destination* only. There's a separate rule, one you saw in step 3 but didn't need, that would rewrite the *source*:

```plain
iptables-save -t nat | grep 'default/web' | grep MASQ
```{{exec}}

> `-A KUBE-SVC-... ! -s 10.244.0.0/16 -d 10.96.244.124/32 --dport 80 -j KUBE-MARK-MASQ`

Read the condition: `! -s 10.244.0.0/16` — **not** sourced from the pod network. `client` is a Pod, so its address is inside that range, and the rule that would have masqueraded the source never matched. That's why `web` saw `client`'s real address rather than some node-level stand-in — and it's also why `web` could, in principle, apply a NetworkPolicy against `client`'s actual identity. A request arriving from *outside* the cluster would hit this rule, get masqueraded to the node's own address, and `web` would never see the real client at all.

Look at the response half of each capture, too:

```plain
grep 'Flags \[P\.\]' /root/cap-client-side.txt | tail -1
grep 'Flags \[P\.\]' /root/cap-server-side.txt | tail -1
```{{exec}}

> The response leaves `web` from `10.244.0.5.8080`, and arrives at `client` from `10.96.244.124.80` — un-translated back to the ClusterIP, automatically. Nowhere in `iptables-save` is there a rule that does this in the return direction. **`conntrack`** is doing it: the first packet's `DNAT` was recorded against that connection, and every packet after — in both directions — gets the same treatment applied without a matching rule of its own. `iptables-save` only ever shows you the rules; the state that makes a connection consistent lives in the conntrack table, and no static read of the rules will show it to you.

</details>
