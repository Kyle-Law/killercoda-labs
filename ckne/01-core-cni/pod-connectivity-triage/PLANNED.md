# The Drop You Cannot Capture

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Core Infrastructure & CNI (15%) |
| **Exam objective** | Troubleshooting Pod Connectivity (DNS, pod-to-pod) |
| **Mapped tech** | Cilium (dataplane) + Hubble (flow visibility) |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | Ready — Hubble needs nothing installed on this backend |

## What it teaches

The deliberate opposite of [`packet-fault-triage`](../../packet-fault-triage/), which runs in bare
network namespaces precisely so there is no CNI to hide behind. Here the CNI *is* the instrument:
faults that a capture cannot explain, diagnosed from the flow log instead.

Three failures that look identical from the client — a DNS answer that never comes, a pod-to-pod
connection refused, and one silently dropped — separated by where the flow log stops.

## The finding at its heart

`tcpdump` shows you a packet leaving and nothing coming back. It cannot tell you whether the
packet was dropped on the way out, on the way in, or answered by something that then failed.
The flow log records a verdict at each point, and the verdict names the reason.

## Step outline

1. **A connection that hangs.** Reproduce it, capture on the veth, and establish that the capture
   is consistent with three different causes. Then read the same connection in `hubble observe`.
2. **DNS specifically.** A Pod that cannot resolve, where the flow log distinguishes "the query
   never left", "it reached kube-dns and was dropped" and "it was answered with NXDOMAIN".
3. **Refused versus dropped.** The difference between a `DROPPED` verdict and a connection the
   backend actively refused — one is policy or datapath, the other is the application, and the
   remedies share nothing.
4. **The drop with no rule.** A verdict of `policy-verdict:none`, which means no rule matched
   rather than a rule denied — the distinction that decides whether you go looking for the wrong
   policy or for a missing one.

## Must resolve before building

- **Overlap with [`flow-logs-and-drops`](../../flow-logs-and-drops/)**, which already teaches
  `hubble observe` and the `policy-verdict:none` verdict. That lab approaches it from security —
  who is talking to this, and what should be allowed. This one approaches it from triage — it is
  broken, find out where. Step 4 is the seam; decide whether it belongs here at all or whether
  this lab should assume it and go further into DNS.
- Which of the three faults can be injected reproducibly without a policy, so the lab is about
  diagnosis rather than about NetworkPolicy again.

## Cross-links

- Mirror image of [`packet-fault-triage`](../../packet-fault-triage/) — same skill, opposite tooling.
  The intro should say so.
- Assumes [`flow-logs-and-drops`](../../flow-logs-and-drops/) for the `flows` helper.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted — see the conventions in `ckne/README.md`.
