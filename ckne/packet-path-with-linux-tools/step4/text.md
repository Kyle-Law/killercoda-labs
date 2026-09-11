
One request, one connection, two ends. Capture both simultaneously and account for every address that changes between them — and every one that doesn't.

Save `client`'s side to `/root/cap-client-side.txt` and `web`'s side to `/root/cap-server-side.txt`.

Before you look: given what you found in step 3, **predict whether the two captures will differ at all.**

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
sleep 3
```{{exec}}

Compare the opening `SYN` line from each — not just the addresses, everything on the line.

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
sleep 3
```{{exec}}

```plain
echo "--- client side ---"; grep 'Flags \[S\]' /root/cap-client-side.txt | head -1
echo "--- server side ---"; grep 'Flags \[S\]' /root/cap-server-side.txt | head -1
```{{exec}}

Whichever datapath you are on, one thing is identical in both captures: the **sequence number**. That is proof, independent of anything `kubectl` says, that you are looking at the *same packet* at two points on its path rather than at two different requests.

What differs depends entirely on step 3's answer.

<br>

<details><summary>A · kube-proxy — exactly one field changed</summary>

```plain
client side:  10.244.0.6.51866 > 10.96.244.124.80   Flags [S], seq 1254806050
server side:  10.244.0.6.51866 > 10.244.0.5.8080    Flags [S], seq 1254806050
```

Same source `10.244.0.6.51866`. Same `seq`. Exactly one field is different: the destination, `10.96.244.124.80` became `10.244.0.5.8080`. That is every translation this connection went through — there is only the one.

The source address is the detail worth sitting with:

```plain
iptables-save -t nat | grep 'default/web' | grep MASQ
```{{exec}}

> `-A KUBE-SVC-... ! -s 10.244.0.0/16 -d 10.96.244.124/32 --dport 80 -j KUBE-MARK-MASQ`

Read the condition: `! -s 10.244.0.0/16` — **not** sourced from the pod network. `client` is a Pod, so its address is inside that range and the rule that would have masqueraded the source never matched. That is why `web` saw `client`'s real address, and why a NetworkPolicy on `web` could match `client`'s actual identity. A request from *outside* the cluster would hit this rule, get masqueraded to the node's address, and `web` would never learn who it really was.

Now look at the response direction:

```plain
grep 'Flags \[P\.\]' /root/cap-client-side.txt | tail -1
grep 'Flags \[P\.\]' /root/cap-server-side.txt | tail -1
```{{exec}}

> The response leaves `web` from `10.244.0.5.8080` and arrives at `client` from `10.96.244.124.80` — un-translated back to the ClusterIP, automatically. **And nowhere in `iptables-save` is there a rule that does this.**

`conntrack` is doing it. The first packet's `DNAT` was recorded against that connection, and every packet after — in both directions — gets the matching treatment with no rule of its own. `iptables-save` only ever shows you the rules; the state that makes a connection coherent lives in the conntrack table, and no static read of the rules will reveal it.

</details>

<details><summary>B · eBPF socket LB — the two captures are identical</summary>

```plain
client side:  10.244.0.78.33334 > 10.244.0.118.8080   Flags [S], seq 4105806638
server side:  10.244.0.78.33334 > 10.244.0.118.8080   Flags [S], seq 4105806638
```

**Byte for byte the same.** Not one field differs — not the destination, not the port, nothing.

That is not an anticlimax, it is the finding. In step 3 you established that the rewrite happened inside `connect()`, before the kernel built a packet. So by the time this packet first touched an interface it was *already* addressed to `10.244.0.118:8080`, and from there to the far end nothing had any reason to change it. There is no in-flight translation to observe, because there is no in-flight translation.

Confirm nothing on the path is doing NAT for this Service:

```plain
iptables-save -t nat | grep -c 'default/web'
conntrack -L 2>/dev/null | grep 10.244 | head -3 || echo "(conntrack tool not installed)"
```{{exec}}

> `0` iptables rules. There is no DNAT entry to reverse on the way back either — the return packets are already addressed correctly, because the forward ones always were.

The source address point from the kube-proxy case still holds, and for the same reason: `web` sees `client`'s real Pod IP, so identity-based policy works. Cilium applies masquerading only to traffic leaving the cluster.

> **Why this is worth more than the tidy answer.** On the kube-proxy datapath, packet captures reveal the Service translation. Here they conceal it completely — an identical capture at both ends looks like nothing interesting happened. If you did not already know the translation had occurred before the packet existed, you would have no way to find it with `tcpdump` at all, and the eBPF map in step 3 is the only place it is visible.

</details>

</details>
