
## What you found

You assembled the architecture the `inferencepool` Helm chart installs — an `InferencePool`, an endpoint picker Service, and an `HTTPRoute` whose backend is the pool rather than a Service — and then met the three ways it fails while looking healthy.

**The pool is four agreements, none of them validated until traffic flows.** The selector against the Pod labels, `targetPorts` against the *container* port, `endpointPickerRef` against the picker's Service, and its port against the ext_proc port specifically — not health, not metrics. And a fifth that is not in the pool at all: the picker is bound to one pool by `--pool-name`, on the command line, and will not follow a rename.

**A permission it will not start without.** Remove `pods` from its Role and the picker runs and never becomes Ready. Not a crash — a readiness failure, which stalls the rollout and leaves the old replica serving. The only artefact naming RBAC is the picker's own log; the Deployment, the Pod and the events all describe the symptom instead.

**An instruction no Gateway API object can carry.** With the `DestinationRule` deleted, `Gateway` is Programmed, the route is Accepted with references resolved, the pool exists, the picker is Ready and silent — and every request fails in about a millisecond. The picker serves ext_proc over TLS and Istio has to be told. That is a `networking.istio.io` object, which is why the chart takes a `provider.name` flag: its whole job is deciding which vendor object to emit beside the portable ones.

**A field whose two values do the same thing.** With no picker, `FailOpen` and `FailClose` both return `500` with an empty body in six tenths of a millisecond. `FailOpen` means the ext_proc filter does not block — not that the gateway finds its own endpoints. The route's endpoints *come from* the picker, so there are none.

## The shape of it

> Three failures, three healthy-looking clusters, and in each one the only honest witness was a different thing: a Pod's readiness, a component's own log, and a stopwatch.

The sub-millisecond timing in steps 3 and 4 is worth keeping. A request that fails faster than a network round trip did not fail at the far end — it never left. That single observation separates "the backend is broken" from "the routing decision never happened", and no status field will tell you which.

## Where to go next

- **[`inference-gateway`](https://killercoda.com/kylelaw/course/ckne/inference-gateway)** — the other half: the same architecture installed by Helm, and four steps on the picker's *scoring*, including the weighting that makes queue depth structurally unable to win.
- `InferenceObjective` — the picker already watches it; it adds per-workload priority and load shedding once the pool is saturated.
- Run the picker with `--v=4` to see the per-request scores behind each decision.

> **Versions.** Pinned at Inference Extension v1.5.0. At v1.6 the project split — the picker moved to `llm-d/llm-d-router`, leaving the `InferencePool` API and the picker protocol in the extension — so the objects you wrote here outlive the binary that reads them.
