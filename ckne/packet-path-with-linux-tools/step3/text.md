
Make the same request again, but this time through `web`'s Service instead of its Pod IP — and capture on `client`'s own veth while you do it, not `web`'s.

Then find the rule in `iptables-save` that is responsible for the request ever reaching `web` at all, and save it to `/root/dnat-rule.txt`.

<br>

<details><summary>Tip</summary>

`podveth` does what step 1 did by hand — use it to skip straight to `client`'s host interface:

```plain
CVETH=$(podveth client)
CLUSTERIP=$(kubectl get svc web -o jsonpath='{.spec.clusterIP}')
tcpdump -i $CVETH -n -c 10 tcp > /root/cap-service.txt 2>&1 &
sleep 1
kubectl exec client -- wget -qO- -T5 http://$CLUSTERIP/hostname
echo
sleep 2
cat /root/cap-service.txt
```{{exec}}

Look at what address the capture says the request went to. `client` was told to connect to the ClusterIP — did it?

`kube-proxy` writes the routing as `iptables` rules. Look in the `nat` table for a rule mentioning `web` and the word `DNAT`:

```plain
iptables-save -t nat | grep 'default/web'
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
CVETH=$(podveth client)
CLUSTERIP=$(kubectl get svc web -o jsonpath='{.spec.clusterIP}')
echo "capturing on client's own veth, requesting $CLUSTERIP"
tcpdump -i $CVETH -n -c 10 tcp > /root/cap-service.txt 2>&1 &
sleep 1
kubectl exec client -- wget -qO- -T5 http://$CLUSTERIP/hostname
echo
sleep 2
cat /root/cap-service.txt
```{{exec}}

> ```
> 10.244.0.6.35698 > 10.96.244.124.80: Flags [S] ...
> 10.96.244.124.80 > 10.244.0.6.35698: Flags [S.] ...
> ...
> ```

**Every packet on `client`'s own interface — both directions — is addressed to and from the ClusterIP.** Not the Pod IP anywhere. As far as `client`'s network stack is concerned, `10.96.244.124` is a real host that answered a TCP handshake and served an HTTP response. The ClusterIP was never resolved to anything: it was connected to directly, and something further along the path made that work.

```plain
iptables-save -t nat | grep 'default/web'
```{{exec}}

> ```
> -A KUBE-SERVICES -d 10.96.244.124/32 -p tcp -m comment --comment "default/web cluster IP" --dport 80 -j KUBE-SVC-LOLE4ISW44XBNF3G
> -A KUBE-SVC-LOLE4ISW44XBNF3G ! -s 10.244.0.0/16 -d 10.96.244.124/32 --dport 80 -j KUBE-MARK-MASQ
> -A KUBE-SVC-LOLE4ISW44XBNF3G -m comment --comment "default/web -> 10.244.0.5:8080" -j KUBE-SEP-5ORQWIE3QG6L2KWO
> -A KUBE-SEP-5ORQWIE3QG6L2KWO -s 10.244.0.5/32 -j KUBE-MARK-MASQ
> -A KUBE-SEP-5ORQWIE3QG6L2KWO -p tcp --dport 80 -j DNAT --to-destination 10.244.0.5:8080
> ```

```plain
iptables-save -t nat | grep 'default/web' | grep DNAT > /root/dnat-rule.txt
cat /root/dnat-rule.txt
```{{exec}}

Read the chain top to bottom: `KUBE-SERVICES` catches anything addressed to `10.96.244.124:80` and hands it to `KUBE-SVC-...`, which hands it to `KUBE-SEP-...` — one chain per backend Pod, which is the mechanism load balancing across replicas runs on — and *that* chain is where the address actually changes: `DNAT --to-destination 10.244.0.5:8080`. The ClusterIP was never a real listening address. It's a name for a `DNAT` target that `kube-proxy` keeps in sync with the Service's Endpoints.

**This is also why the capture in step 3 could never have shown the Pod IP.** `iptables` rewrites the packet as it's forwarded through the *host's* network stack — a hop that happens strictly after it leaves `client`'s veth. Capturing there catches the packet exactly as `client` sent it, before the rewrite exists.

</details>
