
<br>

An LLM request is not one operation, it's two, and they have completely different costs:

```
prefill_time = prefill-overhead + (prompt_tokens × prefill-time-per-token)
decode_time  = (output_tokens − 1) × inter-token-latency
```

**Prefill** runs the model over your whole prompt to produce the first token — its cost grows with **input** length. **Decode** then emits tokens one at a time — its cost grows with **output** length.

Almost every LLM serving decision follows from that split, and it's invisible if you only look at average request duration. Here you'll measure each phase separately, isolate them by zeroing the other, and finish by predicting a request's latency before sending it.

The simulator runs in **echo mode**, where the response mirrors the prompt — so output length always equals input length, and the arithmetic is exact.

> A helper is available: `/root/prompt.sh 60` prints a 60-word prompt.
