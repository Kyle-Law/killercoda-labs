
<br>

### Recap

- **livenessProbe** kills the container on failure (`SIGKILL`, exit code `137`). It is the only probe that can make things worse than the failure it was watching for.
- **readinessProbe** removes the Pod from Service endpoints and does nothing else — no restart, no kill, the process keeps running. `ready=false` on the `EndpointSlice` is the entire mechanism; kube-proxy just stops forwarding.
- **startupProbe** suspends both of the others until it first succeeds, then never runs again. That's what lets a slow boot and fast hang-detection coexist, which a single liveness probe with `initialDelaySeconds` can never do.
- `initialDelaySeconds` is a blind window on **every** restart, not just the first. Sizing it for a worst-case boot buys permanent blindness in steady state.
- A liveness probe aimed at something slow doesn't degrade the app — it prevents it from *ever* starting. Restart count climbing while the Pod never reaches `READY` is the signature.
- Check only *this process* in liveness. A shared dependency in a liveness probe turns one dependency blip into a fleet-wide restart storm; the same check in readiness is a graceful, self-healing withdrawal from traffic.

### WELL DONE!

You've now seen the same broken endpoint produce a `CrashLoopBackOff` and a quiet `Running 0/1` on the same image, decided only by which probe was watching. That choice is the whole game.

Related labs in this set: `troubleshooting/pod-failures` has a probe misconfiguration to diagnose cold, and `ai-workloads/inference-sim` applies the liveness/readiness split to a model server whose readiness genuinely lags its liveness by minutes.
