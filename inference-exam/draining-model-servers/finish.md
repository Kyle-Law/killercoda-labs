## What you found

A deploy replaces a Pod in a fixed order: the replacement becomes Ready, the old Pod leaves the Service's endpoints, its preStop hook runs, then `SIGTERM`, then `SIGKILL` when the grace period runs out. For a request lasting milliseconds none of it matters. For a 50-second answer, every part of it does.

| Configuration | Answer through a deploy | Old Pod gone after |
|---|---|---|
| defaults | 72 of 100 tokens, no `[DONE]`, curl exit 18 | 32s |
| `terminationGracePeriodSeconds: 120` | cut again, about 82 of 100 | 37s |
| + `preStop: exec: [sleep, 60]` | cut again; `FailedPreStopHook` | 38s |
| + `preStop: sleep: {seconds: 60}` | **100 of 100, `[DONE]`, exit 0** | 61s |

**A truncated stream is not an error.** The response began with `200 OK`; every log on the path recorded a success. The only evidence is the missing `[DONE]` and `finish_reason`, which is what to alert on.

**Two clocks, one number.** The kubelet waits 30 seconds by default. This server also waits 30 seconds for in-flight requests after `SIGTERM`, then closes them. With both at 30 there is no telling which one cut the answer; raising the grace period only showed the second clock, in a log line that disappears with the Pod.

**A failing preStop hook is one event.** `FailedPreStopHook` says nothing about why; the Pod terminates on schedule anyway and is gone before anyone looks. An `exec` hook can only run what the image contains, and a minimal image contains no `sleep`.

**Delay the signal, not the kill.** The `sleep` action holds `SIGTERM` back while the Pod is already out of the endpoints: new requests go to the replacement, answers in flight finish, and the server then has nothing left to drain. It must fit inside the grace period, and it costs its full length on every termination.

## The shape of it

> The fix for "it was killed too soon" was not more time before the kill. It was more time before the *warning*.

Graceful shutdown is a contract between the platform and the process, and both sides have a timer. Kubernetes can only control its own side; the preStop sleep works because it moves the moment the process's timer starts.

## Where to go next

- **[`probes/readiness-and-safe-rollouts`](https://killercoda.com/kylelaw/course/probes/readiness-and-safe-rollouts)** — the other end of the same rollout: sending traffic to the new Pod only when it can serve.
- **[`ckne/llm-routing`](https://killercoda.com/kylelaw/course/ckne/llm-routing)** — the other way a streamed answer stops halfway: a proxy timeout, also logged as `200`.
- Find your real model server's shutdown timeout before you size the sleep. It is the number this lab could only discover from a log.

> **Versions.** Run on Kubernetes v1.37 with `llm-d-inference-sim` v0.11.2. The simulator's 30-second drain is specific to it.
