<br>

A web request lasts milliseconds. When Kubernetes replaces a Pod, it takes the Pod out of the Service, sends `SIGTERM`, waits, and kills it. Every request in flight finished long before any of that mattered.

An LLM answer **streams for tens of seconds**. The same sequence now lands in the middle of a sentence, on every deploy, for every user mid-answer, and nothing reports an error: the response already began with `200 OK`, so all the client sees is a stream that stops.

Already running in namespace `serve` (your current namespace):

| Object | What it is |
|---|---|
| Deployment `chat` | one replica of [`llm-d-inference-sim`](https://github.com/llm-d/llm-d-inference-sim), a vLLM-compatible simulator with no GPU. It echoes the prompt back one token every **500ms**, so a 100-word prompt is a 50-second answer |
| Service `chat` | in front of it, port 8000 |
| Pod `cli` | the client the helpers send requests from |

Two helpers do the plumbing so you can concentrate on the configuration:

- `llmstream [WORDS]` — one streamed answer, nothing else going on. Prints how many chunks arrived, whether the closing `[DONE]` came, the `finish_reason`, and curl's exit code.
- `drill` — what a deploy does to an answer in flight. Starts a 100-token stream, runs `kubectl rollout restart` five seconds in, and reports how the stream ended and how long the old Pod took to go. Every run is recorded in `/root/drills.log` with the configuration it ran against, and the checks read that record.

```plain
llmstream 6
```{{exec}}

Each step is checked with the **CHECK** button. When a check does not pass, run `why`{{exec}} in the terminal — every check in this lab writes down which condition it was not happy with, rather than leaving you to guess.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
