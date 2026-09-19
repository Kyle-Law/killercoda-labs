
This one is the reason the chart has a flag for which gateway you are using.

Delete the `DestinationRule` named `llm-epp` and send a request. Then go and check every Gateway API object in the path — the `Gateway`, the `HTTPRoute`, the `InferencePool`, the picker's Pod — and compare what they claim with what is happening.

Write what you find to `/root/answers/step3.txt`, then restore it.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

```plain
kubectl get destinationrule llm-epp -o yaml
```{{exec}}

A copy is saved at `/root/destinationrule.yaml` so you can put it back.

When every object says it is fine and traffic is not, the question to ask is what the objects *cannot* describe.

</details>

<details><summary>Solution</summary>

```plain
kubectl delete destinationrule llm-epp
sleep 10
poolcall
```{{exec}}

> ```
>   http=500   time=0.004456s
>   body:
> ```

Now audit everything:

```plain
kubectl get gateway inference-gateway
kubectl get httproute llm-route -o jsonpath='{.status.parents[0].conditions}' | tr ',' '\n' | grep -E 'type|status'
kubectl get inferencepool llm-pool
kubectl get pods -l app=llm-epp
pickerlog
```{{exec}}

> `PROGRAMMED True` · `Accepted True` · `ResolvedRefs True` · pool exists · picker `1/1 Running`.

**Every object in the path reports itself healthy, and every request fails.**

Look carefully at what the picker is saying about these requests: **nothing**. If you did step 2 you will still see its `pods is forbidden` errors in the log — those are old, from a Pod that has since been fixed, and no new error joins them however many requests you send. The gateway never successfully reached the picker, so there is nothing for it to complain about.

The missing piece:

```plain
cat /root/destinationrule.yaml
```{{exec}}

> ```yaml
> spec:
>   host: llm-epp.default.svc.cluster.local
>   trafficPolicy:
>     tls:
>       mode: SIMPLE
>       insecureSkipVerify: true
> ```

**The picker serves its ext_proc endpoint over TLS.** Istio, left to itself, calls that Service in plaintext, the handshake never happens, and the gateway fails the request before it has anywhere to send it — in a few milliseconds, which is the tell. A model server answers in tens of milliseconds even when it is idle, so a failure this fast never reached one.

```plain
kubectl apply -f /root/destinationrule.yaml
sleep 10
poolcall
```{{exec}}

```plain
cat > /root/answers/step3.txt <<'EOF'
With the DestinationRule deleted, every Gateway API object still reported healthy
-- Gateway Programmed, HTTPRoute Accepted and ResolvedRefs, pool present, picker
1/1 Ready with no errors -- and every request returned 500 in about a millisecond.
The picker serves ext_proc over TLS and Istio has to be told to use it. No field
in the Gateway, HTTPRoute or InferencePool can express that, so it takes a
vendor-specific DestinationRule.
EOF
cat /root/answers/step3.txt
```{{exec}}

> **This is the portability seam.** The `Gateway`, the `HTTPRoute` and the `InferencePool` moved here unchanged from any other implementation — that part of Gateway API really is portable. The instruction that makes them *work* is a `networking.istio.io` object, and on another gateway it is a different object with a different name, or a flag, or nothing at all because that implementation handles it internally.
>
> It is also why the Helm chart takes `--set provider.name=istio`. That flag does not configure the pool or the picker. Its entire job is to decide which vendor-specific object to emit alongside them — and if you assemble the pool by hand, as you just did, nothing emits it for you.

</details>
