
<br>

### Recap

- The simulator is a **drop-in stand-in for vLLM**: OpenAI-compatible API, vLLM metric names, modelled prefill/decode latency — with no GPU, no weights, and a 41 MB image.
- Leaving `render-url` unset keeps it standalone. Upstream's own manifest pairs it with a 1.15 GB tokenizer sidecar you only need for real HuggingFace tokenisation.
- `mode: echo` makes responses deterministic, which is what turns it from a demo into something you can write assertions against.
- `/health` and `/health/ready` are **different questions** — process alive vs. ready for traffic. On a real server the second can lag the first by minutes while the model loads, which is why pointing liveness at readiness restarts a Pod forever.
- `X-Return-Error` injects failures per request without touching config, so you can test how routers, retries and alerts behave against a degraded backend.
- Queue depth (`vllm:num_requests_waiting`), not CPU, is the meaningful autoscaling signal for inference.

### WELL DONE!

You can now build and test inference infrastructure — routing, probes, scaling policy, dashboards, alerts — without a GPU anywhere in sight.
