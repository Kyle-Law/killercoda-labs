
There is a second model in the cluster: `tiny-embed`, served by the `embed` Deployment, behind the `embed` Service.

Send a normal OpenAI-style request asking for it — the way any client library would — and see where it lands:

```plain
GW=$(gwaddr)
kubectl exec cli -- curl -s -m 30 -X POST "http://$GW/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d '{"model":"tiny-embed","messages":[{"role":"user","content":"hello"}],"max_tokens":40}'
```{{exec}}

Make that request reach the right backend. Then answer the harder question: **why can't Gateway API route on the model name directly?**

<br>

<details><summary>Tip</summary>

Look at what an `HTTPRoute` is actually allowed to match on:

```plain
kubectl explain httproute.spec.rules.matches
```{{exec}}

Compare that list against where the model name appears in the request you just sent.

</details>

<details><summary>Solution</summary>

```plain
GW=$(gwaddr)
kubectl exec cli -- curl -s -m 30 -X POST "http://$GW/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d '{"model":"tiny-embed","messages":[{"role":"user","content":"hello"}],"max_tokens":40}'
```{{exec}}

> ```
> {"error":{"message":"The model `tiny-embed` does not exist.","type":"NotFoundError","code":404}}
> ```

The request went to a `demo-model` server, which correctly reported that it has never heard of `tiny-embed`. The route sent it there because, as far as the proxy is concerned, there was nothing to distinguish it.

```plain
kubectl explain httproute.spec.rules.matches
```{{exec}}

> `headers`, `method`, `path`, `queryParams`.

**That is the entire list, and the model name is in none of them.** In the OpenAI API the model is a field in the JSON *body* — and Gateway API has no body matcher. Neither does Ingress. The one identifier that matters most for routing inference traffic is the one an HTTP router structurally cannot see.

What you *can* match on is a header, so lift it out of the body:

```plain
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: chat-route
spec:
  parentRefs:
  - name: llm-gateway
  rules:
  - matches:
    - headers:
      - name: x-model
        value: tiny-embed
    timeouts:
      request: "0s"
      backendRequest: "0s"
    backendRefs:
    - name: embed
      port: 80
  - timeouts:
      request: "0s"
      backendRequest: "0s"
    backendRefs:
    - name: chat
      port: 80
EOF
sleep 10
```{{exec}}

```plain
echo "--- with the header ---"
kubectl exec cli -- curl -s -m 30 -X POST "http://$GW/v1/chat/completions" \
  -H 'Content-Type: application/json' -H 'x-model: tiny-embed' \
  -d '{"model":"tiny-embed","messages":[{"role":"user","content":"hello"}],"max_tokens":40}' | head -c 150
echo; echo "--- without it, body unchanged ---"
kubectl exec cli -- curl -s -m 30 -X POST "http://$GW/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d '{"model":"tiny-embed","messages":[{"role":"user","content":"hello"}],"max_tokens":40}' | head -c 150
echo
```{{exec}}

> With the header: a real completion, `"model":"tiny-embed"`.
> Without it: the same `404` as before.

It works — and notice what it costs. **Every client must now set a header that duplicates a field already in the body, and the two can disagree.** Nothing validates that `x-model` matches `model`; send `x-model: tiny-embed` with `"model":"demo-model"` and you will be routed to one server and rejected by it. No standard client library sets that header, so this only works for callers you control.

> **What production actually does.** This gap is exactly why the [Gateway API Inference Extension](https://gateway-api-inference-extension.sigs.k8s.io/) exists. It adds `InferencePool` and an *endpoint picker* — an external process the gateway consults per request, which reads the body to get the model name **and** scrapes each replica's `vllm:num_requests_waiting` to choose the least-loaded one. That single component closes both this gap and step 2's: body-aware routing and queue-aware balancing are the same problem, solved in the same place, because both need to understand the request rather than merely forward it.

</details>
