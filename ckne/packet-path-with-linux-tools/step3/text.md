
Make the same request again, but through `web`'s **Service** this time instead of its Pod IP — and capture on `client`'s own veth while you do it.

Look at the destination address in the capture, and answer the question it raises: **is it the ClusterIP, or the Pod IP?**

Your answer tells you which datapath this cluster runs. Then find where that datapath actually keeps the translation, and save the proof to `/root/svc-translation.txt`.

<br>

<details><summary>Tip</summary>

```plain
CVETH=$(podveth client)
CLUSTERIP=$(kubectl get svc web -o jsonpath='{.spec.clusterIP}')
tcpdump -i $CVETH -n -c 10 tcp > /root/cap-service.txt 2>&1 &
sleep 1
kubectl exec client -- wget -qO- -T5 http://$CLUSTERIP/hostname
echo
sleep 3
cat /root/cap-service.txt
```{{exec}}

Two commands establish which datapath you are on:

```plain
kubectl -n kube-system get ds kube-proxy
iptables-save -t nat | grep -c KUBE-SVC
```{{exec}}

And this dumps the service translation from both possible places, so you can see which one is populated:

```plain
svctable web
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
CVETH=$(podveth client)
CLUSTERIP=$(kubectl get svc web -o jsonpath='{.spec.clusterIP}')
echo "capturing on $CVETH, requesting $CLUSTERIP"
tcpdump -i $CVETH -n -c 10 tcp > /root/cap-service.txt 2>&1 &
sleep 1
kubectl exec client -- wget -qO- -T5 http://$CLUSTERIP/hostname
echo
sleep 3
grep 'Flags \[S\]' /root/cap-service.txt | head -1
```{{exec}}

Now find out which cluster you are on:

```plain
kubectl -n kube-system get ds kube-proxy 2>&1 | tail -1
iptables-save -t nat | grep -c KUBE-SVC
```{{exec}}

**There are two correct answers, and which one you got matters more than the capture itself.**

<br>

<details><summary>A · You saw the <strong>ClusterIP</strong> — this cluster runs kube-proxy</summary>

```plain
10.244.0.6.35698 > 10.96.244.124.80: Flags [S], seq ...
```

Every packet on `client`'s interface, both directions, is addressed to the ClusterIP. The Pod IP appears nowhere. As far as `client`'s network stack is concerned, `10.96.244.124` is a real host that answered a TCP handshake.

It isn't. `kube-proxy` wrote rules that rewrite it in flight:

```plain
iptables-save -t nat | grep 'default/web' | tee /root/svc-translation.txt
```{{exec}}

> ```
> -A KUBE-SERVICES -d 10.96.244.124/32 --dport 80 -j KUBE-SVC-LOLE4ISW44XBNF3G
> -A KUBE-SVC-...  -j KUBE-SEP-5ORQWIE3QG6L2KWO
> -A KUBE-SEP-...  -p tcp -j DNAT --to-destination 10.244.0.5:8080
> ```

`KUBE-SERVICES` catches anything for the ClusterIP and hands it to a per-Service chain, which hands it to one chain per backend Pod — that is where load balancing across replicas lives — and *that* chain does the `DNAT`.

**The ClusterIP was never a real listening address.** It is a name for a `DNAT` target that `kube-proxy` keeps in sync with the Service's Endpoints. And the capture could not have shown the Pod IP, because `iptables` rewrites the packet as it is forwarded through the *host's* stack — a hop that happens strictly after it left `client`'s veth.

</details>

<details><summary>B · You saw the <strong>Pod IP</strong> already — this cluster runs eBPF socket load balancing</summary>

```plain
10.244.0.78.34568 > 10.244.0.118.8080: Flags [S], seq ...
```

The destination is already the backend Pod's address **and its target port** — `8080`, not the Service's port `80`. And:

```plain
kubectl -n kube-system get ds kube-proxy 2>&1 | tail -1
iptables-save -t nat | grep -c KUBE-SVC
```{{exec}}

> `Error from server (NotFound): daemonsets.apps "kube-proxy" not found`, and `0`.

There is no kube-proxy and there are no iptables service rules, because Cilium replaced both. The translation still happened — just somewhere you cannot capture:

```plain
kubectl -n kube-system exec ds/cilium -c cilium-agent -- \
  cilium-dbg status --verbose | grep -A4 'KubeProxyReplacement Details'
```{{exec}}

> ```
> KubeProxyReplacement Details:
>   Status:               True
>   Socket LB:            Enabled
>   Socket LB Coverage:   Full
> ```

**`Socket LB: Enabled` is the whole explanation.** Cilium attaches a BPF program to the cgroup's `connect()` hook. When `client` calls `connect()` to the ClusterIP, that program rewrites the destination *inside the syscall* — before the kernel has built a packet at all. By the time anything reaches a network interface, it was always addressed to the Pod.

You cannot capture a translation that happens before the packet exists. Read the map instead:

```plain
CLUSTERIP=$(kubectl get svc web -o jsonpath='{.spec.clusterIP}')
kubectl -n kube-system exec ds/cilium -c cilium-agent -- \
  cilium-dbg service list | grep -E "Frontend|$CLUSTERIP" | tee /root/svc-translation.txt
```{{exec}}

> ```
> ID   Frontend               Service Type   Backend
> 6    10.96.37.131:80/TCP    ClusterIP      1 => 10.244.0.118:8080/TCP (active)
> ```

Same information as the iptables chain — same ClusterIP, same backend, same port rewrite — held in an eBPF map instead of a chain of rules.

</details>

<br>

> **This is the part worth keeping.** A great deal of Kubernetes networking knowledge is really iptables knowledge, and it quietly stops being true the moment a cluster runs an eBPF datapath. `iptables-save` comes back empty, and the instinct is to conclude the Service is broken. It isn't — you are looking in a place that is no longer used. **Establish which datapath you are on before you start reading rules**, and the two commands at the top of this step are how.

</details>
