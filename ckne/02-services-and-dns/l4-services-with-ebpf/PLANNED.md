# A Service With No Rules Behind It

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Service Networking & DNS (25%) |
| **Exam objective** | Configuring L4 Services |
| **Mapped tech** | Cilium (eBPF kube-proxy replacement for L4 load balancing) |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | Ready — this is the backend's own datapath |

## What it teaches

The first sub-topic of the heaviest domain, and the repo has nothing on it. A Service is an
abstraction with an implementation, and on this cluster the implementation is an eBPF map rather
than a chain of rules — which changes what "configuring" one even means.

`ClusterIP`, `NodePort` and `LoadBalancer` as three different frontend shapes over the same
backend set; `sessionAffinity` implemented without conntrack; and the backend state machine
(`active`, `terminating`, `quarantined`) that has no equivalent in the iptables datapath at all.

## The finding at its heart

`cilium-dbg service list` is the Service — not a view of it, not a cache of it. Everything the
API object says has to end up in that map or it does not happen.

## Step outline

1. **Read the map.** Create a Service, find its frontend in `cilium-dbg service list`, and match
   every field back to the object: the frontend address, the backend set, the port rewrite.
2. **Three frontends, one backend set.** Add a `NodePort`, then a `LoadBalancer`. Watch entries
   appear that share backends. The Service type is a property of the frontend, not the workload.
3. **Session affinity without conntrack.** Turn on `sessionAffinity: ClientIP` and find where the
   decision is stored, given there is no conntrack entry doing it.
4. **Backend states.** Scale down and catch a backend in `terminating` — it still serves existing
   connections and takes no new ones, which is the graceful-shutdown behaviour the iptables
   datapath cannot express.

## Must resolve before building

- Whether a `LoadBalancer` Service is meaningful here: with no load-balancer controller it stays
  `<pending>` forever (the same fact that makes a Gateway never reach `Programmed` — see
  `ckne/README.md`). Step 2 may need to state that plainly rather than trip over it.
- Whether `terminating` state is observable long enough to catch reliably, or whether the step
  needs a deliberately slow `preStop` hook to hold the window open.

## Cross-links

- Depends on the datapath established in [`packet-path-with-linux-tools`](../../packet-path-with-linux-tools/)
  step 3 — that lab finds the map; this one reads and configures through it.
- Pairs with [`kube-proxy-and-the-datapath`](../kube-proxy-and-the-datapath/), which asks the
  comparative question. Build this one first; it is the concrete half.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted — see the conventions in `ckne/README.md`.
