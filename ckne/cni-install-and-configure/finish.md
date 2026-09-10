
<br>

**Installing a CNI puts two things on a node.** One binary in `/opt/cni/bin`, one JSON file in `/etc/cni/net.d`. Everything else the chart creates — agent, operator, CRDs — exists to keep those two useful. The kubelet knows nothing about CNI vendors: it reads the lowest-numbered valid `.conflist` in that directory and runs the plugins it names.

**Break either half and you get a different symptom.** No config: node `NotReady`, `cni plugin not initialized`, Pods `Pending` because a `NotReady` node is tainted `NoSchedule` — they never even got assigned. No binary: node stays `Ready`, Pods reach `ContainerCreating` and stick, `failed to find plugin ... in path`. A cluster that is `Ready` but can't start Pods is a different problem from one that never went `Ready`.

**`hostNetwork` is why you can still debug any of this.** The control plane shares the node's address and never touches the pod network, which is what keeps `kubectl` alive through a CNI outage. It cuts the other way too: NetworkPolicy doesn't apply to `hostNetwork` Pods, so "contain it with a deny-all" quietly does nothing to one.

**Addresses are not a network.** Fifteen lines of JSON naming `ptp` and `host-local` will get a single node to `Ready` with Pods that can reach each other and resolve DNS. It will also accept, store and completely ignore every NetworkPolicy you write. The API server validates policy; the CNI enforces it — and nothing warns you when there's nobody home. Testing a connection you expect to be blocked is the only way to know.

**Static IPAM is the thing that doesn't scale.** `host-local` allocates from a range written into a file on one node, which is fine until there is a second node. A real CNI moves that decision into a component that can see the whole cluster — which is why Cilium's conflist has no address range in it at all.

**A CNI only manages endpoints it created.** Installing one over a running cluster changes nothing for Pods that are already up; they have to be recreated. That is the step people miss during migrations, and the symptom is a policy that mysteriously applies to new Pods and not old ones.

**Deleting a controller does not undo what it wrote.** `kube-proxy`'s iptables rules survive the DaemonSet and keep working, so "the Service still resolves" proves nothing until you flush them. That habit generalises: when you replace a component that programs the kernel, the test is only meaningful after the old state is gone.

## What this unblocks

This cluster now has `kubeProxyReplacement=true` and Hubble collecting flows, which is the platform the rest of the CKNE material assumes:

- [`ckne/02-services-and-dns/kube-proxy-and-the-datapath`](../02-services-and-dns/kube-proxy-and-the-datapath/) — iptables vs IPVS vs eBPF, at scale
- [`ckne/05-observability/flow-logs-and-drops`](../05-observability/flow-logs-and-drops/) — Hubble as a debugging tool rather than a demo
- [`ckne/04-security-and-policy/pod-identity-and-l7`](../04-security-and-policy/pod-identity-and-l7/) — identity-based policy, the `ID:` numbers in the Hubble output above

For NetworkPolicy itself, [`netpol/allow-only-and-default-deny`](../../netpol/allow-only-and-default-deny/) and [`netpol/egress-and-the-dns-trap`](../../netpol/egress-and-the-dns-trap/) pick up exactly where step 2 left off — on a cluster where policy is enforced.

> Everything here was done on a single node, which hides the hardest part of the job: getting a packet from a Pod on one node to a Pod on another. [`ckne/01-core-cni/ipam-and-pod-cidr`](../01-core-cni/ipam-and-pod-cidr/) takes that on.
