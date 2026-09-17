# The Field That Silently Overrides Another

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Service Networking & DNS (25%) |
| **Exam objective** | Configuring and Troubleshooting Cluster DNS |
| **Mapped tech** | Kubernetes-generic (CoreDNS) |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | Ready — stock Kubernetes, no CNI dependency. One thing to confirm first, below. |

## What it teaches

A Pod with `hostNetwork: true` and the default `dnsPolicy: ClusterFirst` cannot resolve
Service names at all — and nothing says why. `ClusterFirst` is silently ignored whenever
`hostNetwork` is set; the Pod gets the *node's* `/etc/resolv.conf` instead of the cluster's,
with no event, no warning, no status field, no admission rejection. The field you set and
the behaviour you get have quietly stopped being related.

This is the same shape as the `pod-identity-and-l7` finding already in this repo: a thing
that is accepted is not a thing that does anything.

## The finding at its heart

Two Pods, identical `dnsPolicy`, one extra field on one of them — and only one of them can
resolve `web`. `kubectl get pod -o yaml` shows nothing wrong with either.

## Step outline

1. **Reproduce it.** Two Pods, same `dnsPolicy: ClusterFirst`, one with `hostNetwork: true`.
   One resolves `web`; the other doesn't. Predict which, before running it.
2. **Find out why without being told.** Read `/etc/resolv.conf` inside each Pod rather than
   trusting the spec. The host-networked Pod is reading the *node's* resolver config —
   `ClusterFirst` never took effect, and nothing on the Pod object says so.
3. **Fix it.** `dnsPolicy: ClusterFirstWithHostNet` restores cluster DNS for a
   host-networked Pod. Verify the fix the same way step 2 found the problem: read the file,
   don't trust the field.
4. **`dnsPolicy: None`, and the trap in it.** `None` ignores the cluster resolver
   entirely and requires `dnsConfig` to supply nameservers — set `None` alone with no
   `dnsConfig` and the Pod is rejected outright at admission, the one case in this lab where
   Kubernetes actually does refuse a bad combination rather than silently degrading. Contrast
   the two failure modes: `hostNetwork` degrades silently, a bare `None` fails loudly.

## Must resolve before building

- **Which real workloads use `hostNetwork` on this backend**, so step 1 reproduces a
  believable scenario rather than an invented one — a CNI agent or a monitoring DaemonSet
  are the usual candidates, and either would ground the lab in something the learner will
  actually meet.

## Cross-links

- Same shape as `pod-identity-and-l7`'s finding (acceptance without effect) — worth an
  explicit callback in the lab text, not a repeated build.
- Assumes nothing from `coredns-customization` or `dns-resolution-cost`; this is a Pod-spec
  question, not a Corefile or resolver-behaviour one, so it can be built independently of
  either.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted — see the conventions in `ckne/README.md`.
