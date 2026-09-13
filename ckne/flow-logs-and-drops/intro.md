
<br>

The `netpol/` labs have a recurring problem: when a NetworkPolicy blocks something, the only evidence is a connection that hangs. You infer the cause. You cannot see it.

This lab removes the guessing. **Hubble** records every flow the CNI handles — who sent it, who received it, whether it was forwarded or dropped, and *which policy decided*. Applied to NetworkPolicy, it turns a silent timeout into a line of text naming both ends and the verdict.

Nothing needs installing. This backend already runs Cilium with Hubble enabled in the agent, which is where the flow buffer lives — `hubble-relay` only exists to aggregate across nodes, and there is one node here.

Four workloads are running:

| Workload | What it does |
|---|---|
| `api` | the backend everything wants |
| `web` | calls `api` every 2s — the legitimate caller |
| `scanner` | also calls `api`, every 3s — **nobody authorised this** |
| `cli` | a shell to make requests from |

The `scanner` has been there since before you arrived. Finding it is step 3.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
