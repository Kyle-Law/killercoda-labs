
<br>

Serving an LLM normally needs a GPU, a multi-gigabyte model download, and non-deterministic latency — none of which belong in a lab, or in most infrastructure tests.

[`llm-d-inference-sim`](https://github.com/llm-d/llm-d-inference-sim) is a simulator that behaves like vLLM without any of that: a ~41 MB Go binary that speaks the **OpenAI API**, emits **real vLLM Prometheus metric names**, and models prefill/decode latency — with no GPU and no model weights.

That makes it a genuinely useful thing to run on Kubernetes: you can build and test the surrounding infrastructure — routing, probes, autoscaling, dashboards, alerts — against something that responds like the real thing.

Over four steps you'll deploy it, configure it through a ConfigMap, wire up its two health endpoints, force it to fail on demand, and scrape the metrics a real vLLM would emit.

> Upstream's own `deployment.yaml` pairs the simulator with a `vllm-openai-cpu` tokenizer sidecar — a 1.15 GB image. You don't need it here: leave `render-url` unset and the simulator uses its built-in tokenizer instead.
