
The simulator is configured to make the two phases impossible to miss:

```plain
kubectl get configmap sim-config -o jsonpath='{.data.config\.yaml}'
```{{exec}}

`prefill-overhead: "2s"` and `inter-token-latency: "200ms"`. So any request should pause for ~2 seconds, then trickle tokens five per second.

Watch it happen with a streaming request — `-N` disables curl's buffering so chunks appear as they arrive:

```plain
curl -sN http://localhost:30800/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"dummy-model","stream":true,"messages":[{"role":"user","content":"one two three four five six seven eight"}]}'
```{{exec}}

You should see a clear pause, then chunks arriving steadily. **That pause is prefill. The trickle is decode.**

Now measure the total, and save it to `/root/baseline`:

```plain
curl -s -o /dev/null -w '%{time_total}\n' http://localhost:30800/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d "{\"model\":\"dummy-model\",\"messages\":[{\"role\":\"user\",\"content\":\"$(/root/prompt.sh 8)\"}]}" \
  | tee /root/baseline
```{{exec}}

<br>

<details><summary>Info: why this is the number that matters</summary>

A user perceives these two phases completely differently. Prefill is dead air — nothing on screen. Decode is text appearing, which feels fast even when it's slow in aggregate.

Two servers with identical *average latency* can feel completely different: 3s prefill + instant decode is a frustrating wait, while 0.2s prefill + steady streaming feels responsive. Reporting only "p95 request duration" hides that entirely — which is why real LLM serving tracks TTFT and time-per-output-token as separate SLIs.

</details>

<details><summary>Info: what the numbers should be</summary>

The prompt is 8 words. In echo mode the response mirrors it, so output is also about 8 tokens:

```
prefill = 2s + (8 × 0ms)      = 2.0s
decode  = (8 − 1) × 200ms     = 1.4s
total                         ≈ 3.4s
```

`prefill-time-per-token` is `0ms` right now, so prompt length doesn't affect prefill yet. That changes in the next step.

</details>
