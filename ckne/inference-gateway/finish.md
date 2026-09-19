
## What you found

The Gateway API Inference Extension puts a decision-maker on the request path. An `InferencePool` groups the replicas; an **endpoint picker** is consulted per request, scrapes each replica's own metrics, and names the one to use. It is the answer to the problem [`llm-routing`](https://killercoda.com/kylelaw/course/ckne/llm-routing) ends on — a proxy that cannot see inside a model server.

It can see inside. That turned out not to be the whole question.

**The backend was not a Service.** That is the structural change. A Service would balance across the replicas itself, which is the behaviour being replaced, so the `backendRef` names an `InferencePool` in its own API group instead.

**Concentrating traffic on one replica was correct.** Prefix-cache affinity sends a repeated prompt back to the replica that already has its intermediate state, because the alternative is recomputing work that exists. A load balancer spreading that evenly would be the broken one.

**A prompt too short to fill one hashed chunk scores nothing** — so a five-character test prompt spreads evenly and looks like the feature is switched off. The feature was working; the test was too small to reach it.

**Then the picker sent sixty requests to a replica with eight queued, while two sat idle.** Nothing was misconfigured. Each scorer returns 0 to 1 relative to the other replicas and is multiplied by its weight, so with `prefix 3, queue 2, KV 2` the owner scores at worst `3 + 0 + 2 = 5` and an idle replica at best `0 + 2 + 2 = 4`. **A full queue removes at most 2 points; the prefix match is worth 3.** Queue depth was measured, scored, and structurally unable to change the outcome.

Changing one integer from 3 to 1 inverted it. Neither value is correct in the abstract — 3 is right for long shared prompts against replicas that never saturate, and wrong the moment they do.

**And the chart owns that ConfigMap**, so the next `helm upgrade` writes the weight back with no warning and no conflict. A value arrived at by experiment has to live in the chart's values, or it is a temporary edit that will be reverted during an unrelated version bump.

## The general shape

> "It can see the metric" and "the metric can affect the outcome" are different questions, and only the second one decides anything.

That distinction survives well past inference routing. A signal can be collected, exported, dashboarded and scored, and still be incapable of changing a decision because something else outweighs it by construction. The arithmetic is usually short, written down somewhere, and never read.

## Where to go next

- **[`llm-routing`](https://killercoda.com/kylelaw/course/ckne/llm-routing)** — the lab this one answers: Envoy's default timeout truncating a stream at `200`, and least-request counting dispatches rather than queues.
- The **[Inference Extension docs](https://gateway-api-inference-extension.sigs.k8s.io/)** for `InferenceObjective` — request priorities and load shedding, which is the next thing you need once the picker is choosing well and there is still not enough capacity.
- The picker's scorers are plugins. Raising its log level (`--v=4`) prints the per-request scores that produced each decision, which is the fastest way to answer "why did it choose *that* one".

> **A note on versions.** This lab pins the Inference Extension at v1.5.0, where one Helm chart installs both the `InferencePool` and the picker. At v1.6 the project split: the picker moved to `llm-d/llm-d-router` and body-based routing to `llm-d/llm-d-inference-payload-processor`, leaving the `InferencePool` API and the picker protocol in the extension. Moving to v1.6+ is a re-architecture, not a version bump.
