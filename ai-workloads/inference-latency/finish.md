
<br>

### Recap

The cost model you measured:

```
prefill_time = prefill-overhead + (prompt_tokens − cached) × prefill-time-per-token
decode_time  = (output_tokens − 1) × inter-token-latency
```

- **Prefill grows with input, decode grows with output.** They are separate costs with separate causes, and a single "request duration" number conflates them.
- **They feel different to a user.** Prefill is dead air; decode is text appearing. Equal totals can be a good or a bad experience depending entirely on the split — which is why TTFT and time-per-output-token are tracked as distinct SLIs.
- **They need different fixes.** Prefill is compute-bound: prefix caching and chunked prefill help. Decode is memory-bandwidth-bound and serial: bigger batches and speculative decoding help. Neither remedy helps the other phase.
- **`n − cached` is the whole argument for prefix caching.** If every request starts with the same 2,000-token system prompt, re-prefilling it each time is pure waste.
- **Splitting the phases across different hardware** is what prefill/decode disaggregation does — the trade being that the KV cache then has to be shipped between them.

### WELL DONE!

You measured how an LLM server spends its time, isolated each phase, and predicted a request from first principles — with no GPU involved.
