<br>

Every autoscaling tutorial starts with CPU. A model server spends its life waiting on an accelerator, so its CPU says almost nothing about how busy it is. What does describe its load is a number it publishes about itself: **how many requests are waiting**.

Getting a `HorizontalPodAutoscaler` to read that number takes a pipeline: the model server exposes it, Prometheus scrapes it, and **prometheus-adapter** serves it to the HPA through the custom metrics API. This lab is that pipeline, where it goes wrong, and what it still cannot do once it is right.

Already running:

| Namespace | Object | What it is |
|---|---|---|
| `serve` (current) | Deployment `chat` | [`llm-d-inference-sim`](https://github.com/llm-d/llm-d-inference-sim), a vLLM-compatible simulator with no GPU. It works on **one request at a time** and takes about 8.6 seconds per answer, so a queue forms as soon as two requests overlap |
| `serve` | HPA `chat` | the autoscaler every tutorial writes: 50% CPU, 1 to 5 replicas |
| `serve` | Pod `cli` | the client the helpers send requests from |
| `monitoring` | Prometheus, prometheus-adapter | the pipeline, on the adapter chart's default rules |

Three helpers:

- `llmload [INTERVAL] [COUNT]` — in the background, one request every INTERVAL seconds, without waiting for answers, the way users arrive. Its summary goes to `/tmp/llmload.out`.
- `llmstats` — each replica's CPU next to what it says about itself: requests **running** and requests **waiting**.
- `llmflood POD [N]` — N requests at once straight to one Pod, bypassing the Service. Step 5 uses it.

```plain
llmstats
```{{exec}}

Each step is checked with the **CHECK** button. When a check does not pass, run `why`{{exec}} in the terminal — every check in this lab writes down which condition it was not happy with, rather than leaving you to guess.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
