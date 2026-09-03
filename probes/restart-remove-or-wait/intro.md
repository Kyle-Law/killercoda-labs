
<br>

Three probes, three genuinely different powers — and the difference is not academic:

- **livenessProbe** — *"would restarting help?"* On failure the kubelet **kills the container**.
- **readinessProbe** — *"should traffic come here?"* On failure the Pod is **removed from Service endpoints**, and nothing else happens.
- **startupProbe** — *"has it finished booting yet?"* While it runs, the other two are **suspended**.

Point liveness at something slow and you get a Pod that restart-loops forever without ever finishing startup — an outage caused entirely by the health check that was supposed to prevent one. That is the first thing you'll see here, and you'll see it happening rather than take it on faith.

One app throughout: [`podinfo`](https://github.com/stefanprodan/podinfo), which serves `/healthz` and `/readyz` as separate endpoints and can be told to fail either one on demand.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
