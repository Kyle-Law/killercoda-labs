
<br>

**A Pod's `eth0` is one end of an ordinary veth pair, and the other end sits on the host next to everything else.** The CNI's whole job, at connect time, was creating that pair. After that it's just Linux, which is why standard Linux tools can see and capture every bit of it — no Kubernetes-aware tooling required.

**Match interfaces by `ifindex`/`iflink`, never by name.** Interface indexes are allocated from one counter shared by the whole kernel, host and every network namespace together — so a Pod's `eth0` reports its peer's real, host-visible number as `iflink`, and searching host interfaces for a matching `ifindex` finds it regardless of what the CNI happened to name it. `ip link show eth0`'s `@ifN` notation is the same information, easier to read by eye.

**A ClusterIP is not an address anything listens on** — but *where* it gets translated depends entirely on the datapath, and the two are nothing alike.

- **With `kube-proxy`**, it's a name for a `DNAT` target in `iptables`, rewritten to a real Pod address by rules kept in sync with the Service's Endpoints. Capture on the client's own interface and you see the ClusterIP, unrewritten — the rewrite is a hop that happens later, in the host's forwarding path.
- **With an eBPF datapath** (Cilium's kube-proxy replacement, `Socket LB: Enabled`), a BPF program on the cgroup's `connect()` hook rewrites the destination *inside the syscall*, before the kernel builds a packet. The wire shows the Pod IP and target port from the very first SYN. There are no iptables rules and nothing to capture, because the translation happened before the packet existed.

**Establish which datapath you're on before you start reading rules.** `kubectl -n kube-system get ds kube-proxy` and `iptables-save -t nat | grep -c KUBE-SVC` answer it in two commands. A great deal of Kubernetes networking knowledge is really iptables knowledge, and it silently stops being true on an eBPF cluster — `iptables-save` comes back empty and the instinct is to think the Service is broken. It isn't; you're reading a place that is no longer used.

**Only the destination gets translated, and that's a `! -s <pod-CIDR>` condition, not an accident.** The `MASQUERADE` rule that would rewrite the *source* explicitly skips traffic already coming from inside the pod network. A Pod calling a Service keeps its real address the whole way; a client outside the cluster doing the same thing gets masqueraded to the node's address, and the backend never sees who it really was.

**On the `kube-proxy` datapath, `conntrack` undoes the rewrite on the way back, and there is no rule for that.** `iptables-save` shows you the forward-direction `DNAT`; the reverse translation on every response packet comes from connection-tracking state, not a second rule. Reading the static rules alone would never have told you the return path works — that's arguably the more important habit this lab is trying to build. (On the eBPF datapath the question doesn't arise: nothing was translated in flight, so there is nothing to reverse.)

**The same request can look completely different depending on where the translation lives.** Captured at both ends, a kube-proxy cluster shows exactly one field changed — the destination. An eBPF cluster shows two byte-identical captures, which looks like nothing happened at all. Both are correct; the packet capture is simply blind to a translation performed before the packet existed. Knowing that is the difference between reading a capture and trusting one.

## Where to go next

- [`ckne/cni-install-and-configure`](../cni-install-and-configure/) — what happens one layer below this: no veth pairs exist at all until a CNI creates them
- [`troubleshooting/services-dns`](../../troubleshooting/services-dns/) — the same DNAT and Endpoints machinery, approached from "why is this broken" instead of "how does this work"
- [`netpol/allow-only-and-default-deny`](../../netpol/allow-only-and-default-deny/) — NetworkPolicy enforcement happens at exactly this packet-forwarding layer, which is why `hostNetwork` Pods (no veth, no pod-network address) sit outside its reach

> `ckne/README.md` — this lab covers the CKNE "Using Linux Tools for Packet-level Issues" objective in Core Infrastructure & CNI, and is the stated foundation for `pod-connectivity-triage` and `kube-proxy-and-the-datapath`.
