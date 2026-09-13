
Point `chat-route` at the **`chat`** Service instead, so both replicas are in play, and put steady load through it:

```plain
llmload 0.4 40 20
```

That launches 40 requests, one every 0.4s, without waiting for the previous one — which is how real inference traffic arrives.

Look at the latency spread it reports, then work out **which replica is actually in trouble** and write its Pod name and its queue depth to `/root/answers/step2.txt`.

Then try the obvious fix — switching the load balancer to least-request — and report honestly whether it helped.

<br>

<details><summary>Tip</summary>

Repoint the route first:

```plain
kubectl patch httproute chat-route --type=json \
  -p='[{"op":"replace","path":"/spec/rules/0/backendRefs/0/name","value":"chat"}]'
sleep 8
llmload 0.4 40 20
```{{exec}}

Compare the median against the p90. If they are wildly apart, the requests are not all having the same experience.

`llmstats` shows each replica's CPU alongside what the model server says about its own queue. Run it **while load is in flight** — afterwards everything has drained and looks fine:

```plain
llmload 0.4 40 20 > /tmp/load.out 2>&1 &
sleep 12
llmstats
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
kubectl patch httproute chat-route --type=json \
  -p='[{"op":"replace","path":"/spec/rules/0/backendRefs/0/name","value":"chat"}]'
sleep 8
llmload 0.4 40 20
```{{exec}}

> ```
>   requests:  40
>   failed:    3
>   median:    0.402251s
>   p90:       33.041161s
>   slowest:   40.002208s
> ```

**A median of 0.4s and a p90 of 33s.** Those are not the same service. Some requests were served instantly; others waited over half a minute, and a few never finished at all. An average would have hidden this completely — it is the *shape* of the distribution that tells you what is happening.

Find out where the slow ones went, while the load is still running:

```plain
llmload 0.4 40 20 > /tmp/load.out 2>&1 &
sleep 12
llmstats
```{{exec}}

> ```
> POD                               CPU_mCORES   RUNNING   WAITING
> chat-fast-6ccf665b78-wgsk9                 4         1         0
> chat-slow-646fb77b4d-kcxz6                 0         1        10
> embed-6fdf786587-4spbq                     0         0         0
> ```

There it is. **One replica is idle. The other has ten requests queued.** The load balancer has been splitting traffic evenly between them the entire time.

```plain
POD=$(kubectl get pod -l speed=slow -o jsonpath='{.items[0].metadata.name}')
echo "$POD is backed up: num_requests_waiting = 10 while chat-fast is idle" > /root/answers/step2.txt
cat /root/answers/step2.txt
```{{exec}}

Round-robin is doing exactly what it promises: an equal *number of requests* to each backend. That is a fine proxy for load when requests cost the same. Here one replica handles 8 at a time and the other handles 1, so equal request counts means wildly unequal load.

Now the fix everyone reaches for — least-request, which sends each request to the backend with the fewest in flight:

```plain
cat <<EOF | kubectl apply -f -
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: BackendTrafficPolicy
metadata:
  name: chat-lb
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: chat-route
  loadBalancer:
    type: LeastRequest
EOF
sleep 12
kubectl get backendtrafficpolicy chat-lb -o jsonpath='{.status.ancestors[0].conditions[0].type}={.status.ancestors[0].conditions[0].status}{"\n"}'
```{{exec}}

```plain
llmload 0.4 40 20
```{{exec}}

> ```
>   failed:    8
>   median:    0.402734s
>   p90:       40.002593s
> ```

**It did not help.** The policy is `Accepted=True` and genuinely programmed into Envoy — you can confirm the cluster's `lb_policy` is `LEAST_REQUEST` — and the latency profile is unchanged.

That is the most useful thing in this lab, so it is worth being precise about why:

**Least-request counts requests the proxy has dispatched and is still waiting on. It knows nothing about what happens after the request arrives.** `chat-slow` accepts every request the proxy sends it, immediately, and *then* queues it internally — 10 deep. From Envoy's side that is one in-flight request, exactly like the one it has to `chat-fast`. The queue is invisible from outside the model server.

Generic load balancing has no way to see it. The only component that knows how backed up a model server is, is the model server.

```plain
kubectl delete backendtrafficpolicy chat-lb
```{{exec}}

</details>
