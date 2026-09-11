
<br>

**Time-to-failure is the cheapest diagnostic you have, and it costs nothing.** A packet that is *dropped* leaves the sender waiting until it gives up; a packet that is *rejected* comes back as an RST or an ICMP error and fails instantly. Before capturing anything, that one observation splits the search space in half — and it is free, because you already ran the command that produced it.

**An instant refusal is ambiguous; a hang is not.** `REJECT --reject-with tcp-reset`, and simply having nothing listening on that address, are indistinguishable from the client. Both give you a connection refused, immediately. Only a capture — or `ss -ltnp` on the far end — tells you which.

**Capture at both ends or you are guessing.** A firewall drop on the path and a missing return route on the server produce byte-identical symptoms at the client: SYN out, nothing back. The question that separates them is "did the request arrive?", and only the far end can answer it. `ip route get <dst>` then says whether a reply could ever have been sent.

**`iptables -L` is not the firewall.** It lists the tables `iptables` created. A rule written through `nft` is enforced identically and is completely invisible to it — and on a current distribution `iptables` is itself a shim over `nf_tables` (`iptables --version` says so). Kubernetes, Docker, firewalld and libvirt all write rules you did not. Check `nft list ruleset` before concluding the firewall is innocent, and remember `-t nat`, `-t mangle` and `-t raw` are separate views that `iptables -L` also omits.

**A packet appearing in `tcpdump` does not mean the kernel accepted it.** `tcpdump` taps the device below the MAC filter, so a frame addressed to the wrong MAC still shows up in the capture and is then silently discarded. The signal is not "did it appear" but "did it appear on one side and never leave the other".

**Some faults only exist at size.** A PMTU black hole — a narrowed link plus the ICMP that would report it being filtered — lets the handshake, the health check and `ping` all succeed, and breaks only responses large enough to need full-size segments. It looks precisely like an application bug, which is where the investigation usually goes first and stays for a day.

## The other five faults

The environment has nine, and you have seen four. The rest are worth running:

```plain
netlab fault random
netlab test
```

| | |
|---|---|
| **2** | `REJECT --reject-with tcp-reset` — instant refusal; the RST's TTL is the router's, not the server's |
| **3** | `REJECT --reject-with icmp-admin-prohibited` — the ICMP's *source address* names the box holding the rule |
| **6** | `DNAT` to a host that does not exist — `ip neigh` shows the target `INCOMPLETE`, stuck in ARP |
| **7** | server bound to `127.0.0.1` — instant refusal with every firewall on every hop empty |
| **9** | a poisoned permanent ARP entry — layer 2, invisible to every IP-level tool, found with `ip neigh` |

`netlab reset` clears any fault; `netlab teardown` removes the namespaces entirely.

## The Kubernetes counterparts

| This lab | In a cluster |
|---|---|
| Silent `DROP` in `FORWARD` on the router | A `NetworkPolicy` your CNI is enforcing, or a `KUBE-` chain from `kube-proxy` |
| Missing return route on the server | A Pod whose node lost its route to another node's pod CIDR |
| An `nft` rule `iptables -L` cannot see | `kube-proxy` in `nftables` mode, or Cilium's eBPF datapath — neither shows up in `iptables -L` |
| PMTU black hole | An overlay (VXLAN, IPsec, WireGuard) whose encapsulation overhead was never subtracted from the pod MTU |
| Poisoned ARP entry | A stale `EndpointSlice`, or a veth that outlived the Pod it belonged to |

## Where to go next

- [`ckne/packet-path-with-linux-tools`](../packet-path-with-linux-tools/) — the same tools on a path that works: veth pairs by `ifindex`, DNAT, and conntrack
- [`ckne/cni-install-and-configure`](../cni-install-and-configure/) — what creates those veth pairs and routes in a real cluster
- [`troubleshooting/services-dns`](../../troubleshooting/services-dns/) — the same order-of-elimination habit, applied to Services and DNS

> `ckne/README.md` — this lab covers the CKNE "Using Linux Tools (iptables, ip, tcpdump) for Packet-level Issues" objective in Core Infrastructure & CNI, and the troubleshooting half of "Troubleshooting Pod Connectivity".
