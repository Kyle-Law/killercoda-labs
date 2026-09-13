
<br>

**Policy is enforced against identity, not addresses.** Cilium resolves a Pod's labels to a security identity, and every flow in the log names it. Restart a Deployment and the Pods get new IPs and the same identity, so policy written against `app=api` never needed updating. That is also why the flow log is readable at all: you see `default/web`, not `10.244.0.37`.

**A default-deny does not name a rule, because no rule fired.** The verdict is `policy-verdict:none ... DENIED` followed by `Policy denied DROPPED` — `none` meaning nothing matched. In an allow-only API the absence of a match *is* the block, so "which policy is dropping this?" is the wrong question. The right one is "which policy should have allowed it, and why doesn't it match?"

**A drop and a broken application look identical from the client.** `curl` reports `000` — no status, no refusal, nothing. Every `netpol/` lab in this repo depends on inferring the cause from that silence. The flow log replaces the inference with both endpoints, the port, the TCP flag and the verdict.

**Write allow-lists from observed traffic, not from memory.** Nobody can correctly enumerate the callers of a service that has been running for a year, and a default-deny applied from intention takes down whatever was forgotten. Observe first, then write policy to match what is actually there. Here that surfaced a `scanner` nobody authorised — and a bare unnamed IP, typically a node health check, which is exactly the kind of caller a confident default-deny severs.

**Bound every verification query by time.** `--last N` returns flows from the buffer regardless of age, including everything from before your change, and will cheerfully confirm the state you were trying to leave. `--since 20s` is what "did my change work?" actually means — the same discipline as zeroing `iptables` counters before re-testing.

**A tight allow-list blocks you too.** After scoping `api` to `app=web`, the lab's own `cli` Pod stopped working. Correct, and worth feeling once: the policy has no notion of who is an operator.

## Where to go next

- [`netpol/allow-only-and-default-deny`](../../netpol/allow-only-and-default-deny/) — the policy semantics themselves; run it again with `flows` open in a second terminal and every silent failure becomes visible
- [`netpol/egress-and-the-dns-trap`](../../netpol/egress-and-the-dns-trap/) — the classic outage, where the flow log shows the DNS packet dying on port 53
- [`ckne/packet-fault-triage`](../packet-fault-triage/) — the same question one layer lower, with `tcpdump` instead of a flow log and no identity labels to help

> `ckne/README.md` — this lab covers the CKNE "Auditing Traffic with Logs" objective in Observability.
