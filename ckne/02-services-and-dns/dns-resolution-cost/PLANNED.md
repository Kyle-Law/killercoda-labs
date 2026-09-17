# What One Hostname Actually Costs

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Service Networking & DNS (25%) |
| **Exam objective** | Configuring and Troubleshooting Cluster DNS |
| **Mapped tech** | Kubernetes-generic (CoreDNS) |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | Ready — stock Kubernetes and CoreDNS, no CNI dependency. Two things to confirm first, below. |

## What it teaches

One `curl api.example.com` from a Pod is not one DNS query. It is four, and eight if the
resolver asks for A and AAAA — three NXDOMAINs against the search path before the real
answer. This is the single largest source of avoidable DNS load in a Kubernetes cluster,
and nothing in Kubernetes surfaces it: no event, no status field, no metric anyone looks at
by default.

The lab is about the **client** side of cluster DNS, which the existing labs never touch —
`/etc/resolv.conf`, `ndots`, the search path — and about the fact that both fixes for it
have costs worth understanding before choosing one.

## The finding at its heart

The number is not one, it is knowable exactly, and you can predict it from a file that is
already in every Pod.

## Step outline

1. **Count them.** Turn on the `log` plugin, make one request from a Pod to an external
   name, and count what CoreDNS actually saw. Establish the surprise before explaining it.
2. **Predict, then measure.** Read `/etc/resolv.conf` — `search`, `ndots:5` — and work out
   the rule: a name with fewer than `ndots` dots is tried against every search domain
   *first*. Predict the query count for `web`, `web.default`, `api.example.com` and
   `api.example.com.`, then verify each prediction against the log. The trailing dot is the
   cheapest fix in existence and costs nothing.
3. **Fix it from the Pod, and find where the fix bites back.** `dnsConfig.options` with a
   lower `ndots`, measured. Then the part people skip: lowering it too far makes
   *cross-namespace* short names (`web.other`) pay an extra failed absolute lookup, so the
   right value depends on which names the workload actually resolves.
4. **Fix it from the server, and account for what it costs.** Enable `autopath` in the
   Corefile, re-measure, then look at what it now has to do to work — watch every Pod in the
   cluster to learn its namespace. Why it is off by default, and the case it silently fails
   to help: a Pod with its own `dnsConfig` or a non-`ClusterFirst` policy.

## Must resolve before building

- **musl vs glibc.** Alpine's resolver handles `ndots` and the search path differently from
  glibc's, and queries A and AAAA in parallel. The existing `coredns-customization` lab uses
  a `dnstools` Pod (Alpine); `agnhost` is Debian-based. Confirm which the numbers in steps 1
  and 2 are being derived from — or make the difference a deliberate contrast, which would
  be a genuinely good fifth step if the counts differ cleanly.
- **Whether A+AAAA doubling is visible on this backend.** If IPv6 is off in the Pod network
  the resolver may not ask for AAAA at all, which halves every number in the lab text.
- **`autopath` availability.** Confirm it is compiled into the CoreDNS image the backend
  ships and that enabling it does not require the `kubernetes` plugin's `pods verified`
  mode, which has its own cost.
- **A counting method robust enough for `verify.sh`.** Parsing the CoreDNS log is the
  obvious one but is sensitive to other traffic in the cluster; a `coredns_dns_requests_total`
  delta around a single request may be steadier. Decide before writing the checks.

## Cross-links

- **Assumes `coredns-customization` step 1.** That lab already teaches turning on the `log`
  plugin and reading its output; build on it rather than repeating it.
- Extends nothing else — the client side of DNS is currently uncovered in this repo.
- `netpol/egress-and-the-dns-trap` is the other DNS-shaped failure, and is about reachability
  rather than cost. They do not overlap.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted — see the conventions in `ckne/README.md`.
