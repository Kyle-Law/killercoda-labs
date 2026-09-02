
<br>

### Recap

- **LLM serving has its own SLIs.** `time_to_first_token_seconds` and `time_per_output_token_seconds` describe an experience that a single request-duration number hides completely — fast start with slow streaming feels nothing like the reverse at the same total.
- **A histogram quantile is an estimate.** With a known 2s TTFT you saw p95 land inside the `(1.0, 2.5]` bucket rather than on `2`. That interpolation error is always there; you just normally can't see it because you don't know the true value.
- **Queue depth is the saturation signal, not CPU.** A server pinned at its `max-num-seqs` limit is fully saturated while its CPU sits near idle — which is exactly why an HPA on CPU will refuse to scale a struggling inference service.
- **Synthetic metrics let you test the pipeline, not the workload.** `--fake-metrics` with a `ramp` generator drove an alert from inactive to firing in about a minute, with no load and no waiting for a real incident. That's how you validate alert rules, routing and dashboards before they matter.

### WELL DONE!

You built the observability half of an inference platform — and tested it — without a GPU, a model, or a real outage.
