
<br>

A `NetworkPolicy` can only ever say **allow**. There is no deny rule, no priority, no ordering — nothing in the API can express "block this". Yet network policy is how you block things, and both halves of that sentence are true at once.

The resolution is the one rule worth memorising:

> A Pod that **no** policy selects accepts everything. A Pod that **any** policy selects is denied by default — for the directions that policy names — and then allowed back only what its rules list.

So you never block traffic. You select a Pod, which denies it, and then you allow the traffic that should survive. Every confusing thing about network policy follows from that inversion — including the fact that adding a policy to tighten one Pod can leave a completely different Pod wide open, and that adding a second policy can only ever *widen* what's permitted, never narrow it.

Three Deployments are running in the `shop` namespace — `web`, `api` and `db` — each serving HTTP on port 9898, and right now all six directions between them are open. Two commands are provided for measuring that:

- `canreach <from> <to>` — one probe, e.g. `canreach web api`
- `matrix` — all six directions as a grid

> Policies are enforced by the **CNI plugin**, not by Kubernetes itself. On a cluster whose CNI ignores them, every policy in this lab would apply cleanly, report no errors, and change absolutely nothing. This backend enforces them.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
