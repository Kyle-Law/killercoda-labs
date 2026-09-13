
<br>

Everything you know about load balancing HTTP assumes requests are small, fast and roughly equal. Inference traffic is none of those things: a single response streams for a minute, one request can cost a hundred times another, and a replica that looks healthy may already have a queue of work it has not started.

This lab puts a real Gateway API proxy (Envoy Gateway) in front of three model servers and breaks it four different ways — each one a default that is correct for ordinary web traffic and wrong for this.

Nothing here needs a GPU. The backends are [`llm-d-inference-sim`](https://github.com/llm-d/llm-d-inference-sim), which speaks the OpenAI API and exports **real vLLM metric names** — including `vllm:num_requests_waiting`, the number that turns out to matter most.

Three model servers are running:

| Deployment | Model | Behaviour |
|---|---|---|
| `chat-fast` | `demo-model` | 8 concurrent, ~10ms per token |
| `chat-slow` | `demo-model` | **1 concurrent**, ~400ms per token |
| `embed` | `tiny-embed` | a different model entirely |

`chat-fast` and `chat-slow` sit behind one Service, `chat`. A real fleet ends up uneven exactly like this — different GPU types, a node under memory pressure, one replica still warming its KV cache.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
