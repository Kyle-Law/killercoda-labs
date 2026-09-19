
<br>

[`llm-routing`](https://killercoda.com/kylelaw/course/ckne/llm-routing) ends on a problem it cannot solve. Round-robin sends work to a replica with a ten-deep queue while another sits idle, and switching to least-request does not help — the proxy counts what it has *dispatched*, and the queue forms inside the model server where no general-purpose load balancer can see it.

The **Gateway API Inference Extension** is the answer to that. An `InferencePool` groups the replicas, and an **endpoint picker** — a process the gateway consults on every single request — scrapes each replica's own metrics and names the one to use.

So it can see the queue. This lab is about what it does with that.

Running here:

| Component | What it is |
|---|---|
| Istio | the Gateway API implementation, gateway only — no sidecars anywhere |
| `vllm-qwen3-32b` | three replicas of a vLLM simulator, serving `Qwen/Qwen3-32B` |
| `vllm-qwen3-32b-epp` | the endpoint picker, consulted per request over gRPC |
| `InferencePool` | the three replicas, as one routable thing |

No GPU is involved. The simulator speaks the OpenAI API and exports **real vLLM metric names**, which is exactly what the picker reads.

Three helpers are installed. `igload <count> [same|diff|long] [parallelism]` sends load and prints how many requests **each replica served during that run** — a delta, not a total, because the counters are cumulative and restarting anything resets the picker's memory. `igqueue` shows what each replica is working on right now. `igcount` shows the raw totals.

Each step is checked with the **CHECK** button. When a check does not pass, run `why`{{exec}} in the terminal — every check in this lab writes down which condition it was not happy with, rather than leaving you to guess.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
