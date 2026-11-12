# The Answer That Stops Mid-Sentence

> **Status:** planned, not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **Topic** | Pod termination for long-lived streaming requests: two clocks, and a hook that fails quietly |
| **Domain** | Model server lifecycle and delivery (15%) |
| **Proposed backend** | `kubernetes-kubeadm-1node`, `llm-d-inference-sim` v0.11.2 (already pulled by `ai-workloads/`) |
| **Feasibility** | **Ready.** Every step observed below |

## What it teaches

An LLM response streams for tens of seconds. A web request finishes in milliseconds, so the default
termination path (endpoint removed, SIGTERM, 30 seconds, SIGKILL) is invisible for a web app and fatal
for a model server: every rollout truncates the answers in flight. The client sees no error status;
the stream just ends without its `[DONE]`.

The instinctive fix is the wrong one, or rather half of one.

## The finding at its heart

**There are two clocks, and raising the one you know about exposes the one you don't.** With the
default `terminationGracePeriodSeconds: 30` the kubelet kills the server mid-stream. Raise it to 120
and the stream is *still* cut at the same point, because the server runs its own 30-second drain
after SIGTERM and then closes the connection itself. Only its log says so.

The fix that works is to not send SIGTERM yet: a preStop hook delays it while the Pod is already out
of the Service's endpoints, so in-flight streams finish and new requests go elsewhere. And the obvious
preStop, `exec: ["sleep", "60"]`, fails because the image has no `sleep` binary. That failure is an
event, the kubelet carries on with SIGTERM at once, and the stream is cut exactly as before.

## Observed (kind, Kubernetes v1.37.0, simulator v0.11.2)

A 100-token streamed answer at `--inter-token-latency=500ms` takes about 50 seconds undisturbed. Each
row restarts the Deployment (or deletes the Pod) 5 seconds into the stream.

| Configuration | Chunks received | Stream end | Old Pod gone after |
|---|---|---|---|
| defaults (grace 30s) | 72 / 100 | no `[DONE]`, no `finish_reason`, curl exit 18 | 32s |
| grace 120s | 83 / 100 (80 on a rerun) | same | 38s |
| grace 120s + `exec: [sleep, 60]` preStop | 80 / 100 | same, plus `FailedPreStopHook: PreStopHook failed` | 36s |
| grace 120s + `lifecycle.preStop.sleep.seconds: 60` | **100 / 100** | `[DONE]`, `finish_reason: stop`, curl exit 0 | 62s |
| idle Pod, defaults | n/a | n/a | 3s |

The simulator's log across the grace-120s run, which is the whole of step 2:

```
03:44:51 "Shutdown signal received, shutting down servers gracefully"
03:44:51 "Waiting for all in-flight requests to finish"
03:45:21 "Drain timed out, proceeding with shutdown" open_requests=1
03:45:26 "HTTP shutdown timed out, forcing close"
```

The 30-second drain is hard-coded: `--help` on v0.11.2 lists no drain or shutdown flag.

During the preStop sleep the EndpointSlice showed the old Pod `ready=false serving=true
terminating=true` and the new one `ready=true`; a new request sent then completed normally, so the
sleep costs no availability. It does cost time: every Pod now takes about 60 seconds to terminate, idle
or not.

## Step outline

1. **The answer that stops at 72%.** A helper streams a long answer and prints chunks received, whether
   `[DONE]` arrived, and curl's exit code. Run it, restart the Deployment mid-stream, and find the
   `Killing` event and the 30-second default. Gate: an answer file naming the grace period, and the
   Deployment's `terminationGracePeriodSeconds` raised to at least 90.
2. **Raised, and still cut.** Repeat with the new grace period: the stream stops in the same place.
   The learner must catch the old Pod's log *while it terminates* (`kubectl logs -f` started before the
   restart; the log is gone with the Pod). Gate: an answer file naming the server's drain timeout.
3. **The hook that never ran.** Add the obvious `exec` preStop. The stream is still cut, the Pod still
   goes in about 36 seconds, and nothing is `Failed`. Find `FailedPreStopHook` in the events and work
   out why: there is no shell or `sleep` in the image. Gate: the learner names the event.
4. **Delay the signal, not the kill.** Replace it with the native `sleep` action, make the arithmetic
   work (grace must exceed preStop plus the server's drain), and push a stream through a restart.
   Gate: `lifecycle.preStop.sleep.seconds` set, grace greater than it, and a helper-recorded stream
   that crossed a restart with `[DONE]`.

A Tip in step 4: the cost is that every termination now takes the full sleep, so a rollout of N
replicas with `maxUnavailable: 0` takes about N minutes. Size the sleep to the longest answer you serve,
not to a round number.

## Must resolve before building

- **The backend's Kubernetes version and the `sleep` action.** It worked on v1.37.0 with no feature
  gate. `ai-workloads/dra-devices` already requires 1.34+ on this backend; confirm the field is accepted
  there.
- **What a real vLLM does on SIGTERM.** Not observed. The lab must attribute the 30-second drain to
  *this simulator* and say a real server has its own value to find, not claim vLLM's.
- **The step-4 gate's restart.** Either the learner runs the helper across a restart and the check
  reads its record, or `verify.sh` drives a restart itself (slow: about 60s with the sleep). Prefer the
  record.

## Cross-links

- [`probes/readiness-and-safe-rollouts`](../../probes/readiness-and-safe-rollouts/): the other half of a
  safe rollout, getting traffic *to* the new Pod only when it is ready.
- [`ckne/llm-routing`](../../ckne/llm-routing/) step 1: the other way a stream ends early, the proxy's
  15-second timeout, also with a `200` in the log.
- [`ai-workloads/inference-sim`](../../ai-workloads/inference-sim/): the two health endpoints this lab
  assumes.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted. See the conventions in `ckne/README.md`.
