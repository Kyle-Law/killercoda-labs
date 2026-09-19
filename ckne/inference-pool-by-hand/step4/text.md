
`endpointPickerRef` has a field called `failureMode`. This pool has been running on its default, `FailOpen`, since step 1.

The name makes a promise. Test it: take the picker away entirely and send a request under **each** of the two values, timing both. Then put the picker back and write what you found to `/root/answers/step4.txt`.

Before you run it, predict what `FailOpen` should do.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

```plain
kubectl get inferencepool llm-pool -o jsonpath='{.spec.endpointPickerRef}'; echo
```{{exec}}

`poolcall` prints the time as well as the status. Watch it.

</details>

<details><summary>Solution</summary>

The reasonable prediction: with no picker to ask, a gateway that "fails open" carries on and distributes the request itself — degraded, unintelligent, but serving. That is what the words mean everywhere else.

```plain
kubectl scale deploy llm-epp --replicas=0
kubectl wait --for=delete pod -l app=llm-epp --timeout=60s
poolcall
```{{exec}}

> ```
>   http=500   time=0.000616s
>   body:
> ```

**Nothing is served.** Not degraded — nothing, in six tenths of a millisecond, with an empty body.

Now the other value:

```plain
kubectl patch inferencepool llm-pool --type=merge \
  -p '{"spec":{"endpointPickerRef":{"failureMode":"FailClose","name":"llm-epp","port":{"number":9002}}}}'
sleep 12
poolcall
```{{exec}}

> ```
>   http=500   time=0.000689s
>   body:
> ```

**Identical.** Same code, same empty body, same sub-millisecond timing. From outside, the two values of `failureMode` are indistinguishable when the picker is gone.

`FailOpen` describes the **ext_proc filter**, not the route: it means the filter does not block the request chain when the external processor is unreachable. But the endpoints this route sends to are the ones the picker returns. With no picker there is no endpoint list, so the request continues merrily into a cluster with nothing in it — and fails, immediately.

```plain
kubectl scale deploy llm-epp --replicas=1
kubectl rollout status deploy llm-epp
sleep 15
poolcall
```{{exec}}

```plain
cat > /root/answers/step4.txt <<'EOF'
With the picker scaled to zero, FailOpen returned http=500 in ~0.6ms with an
empty body -- no fallback to distributing the request itself.
FailClose was identical: same code, same empty body, same sub-millisecond time.
The two values are indistinguishable from outside when the picker is gone,
because FailOpen only means the ext_proc filter does not block; the route's
endpoints come from the picker, so with no picker there are no endpoints.
EOF
cat /root/answers/step4.txt
```{{exec}}

> **What this costs you architecturally.** The picker is a hard dependency on the request path, and neither value of `failureMode` changes that. Every request to this pool consults a single Deployment over gRPC, and if it is unreachable the pool serves nothing — no matter how healthy the model servers are, and no matter what the field is set to.
>
> That is a reasonable trade for what the picker buys, but it is a trade, and the field name actively obscures it. Run more than one replica of the picker, and treat it as tier-0 for anything the pool serves.

</details>
