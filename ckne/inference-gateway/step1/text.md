
Put a `Gateway` named `inference-gateway` in front of the model servers, and an `HTTPRoute` named `llm-route` that sends everything to them.

The backend is the part worth thinking about. There is a Service you could point at — but pointing at it would defeat the entire exercise, because a Service load balances across the replicas itself. Route to the `InferencePool` instead.

```plain
kubectl get inferencepool,svc
```{{exec}}

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

Two things are unusual here.

A `backendRef` normally names a Service, and the `kind` and `group` fields default to one. An `InferencePool` is a different kind in a different API group, so both have to be spelled out.

And there is no cloud load balancer on this cluster, so a `Gateway` left to its defaults asks for a `LoadBalancer` Service and waits forever for an address. Istio takes an annotation that makes it a NodePort instead:

```plain
  annotations:
    networking.istio.io/service-type: NodePort
```

</details>

<details><summary>Solution</summary>

```plain
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: inference-gateway
  annotations:
    networking.istio.io/service-type: NodePort
spec:
  gatewayClassName: istio
  listeners:
  - name: http
    port: 80
    protocol: HTTP
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: llm-route
spec:
  parentRefs:
  - name: inference-gateway
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - group: inference.networking.k8s.io
      kind: InferencePool
      name: vllm-qwen3-32b
EOF
sleep 30
kubectl get gateway inference-gateway
```{{exec}}

> ```
> NAME                CLASS   ADDRESS                                             PROGRAMMED
> inference-gateway   istio   inference-gateway-istio.default.svc.cluster.local   True
> ```

`PROGRAMMED   True` is worth a second look if you have met Gateway API on a cluster without a load balancer before. It usually sits at `False` with `AddressNotAssigned` forever. The annotation is the whole difference — the Gateway is fine, it was the Service type that could never be satisfied.

Now send a request:

```plain
PORT=$(kubectl get svc -l gateway.networking.k8s.io/gateway-name=inference-gateway \
  -o jsonpath='{.items[0].spec.ports[?(@.port==80)].nodePort}')
curl -s http://localhost:$PORT/v1/completions -H 'Content-Type: application/json' \
  -d '{"model":"Qwen/Qwen3-32B","prompt":"hello","max_tokens":20}' | head -c 300
echo
```{{exec}}

A `text_completion` comes back. Now try a model that does not exist:

```plain
curl -s http://localhost:$PORT/v1/completions -H 'Content-Type: application/json' \
  -d '{"model":"does-not-exist","prompt":"hello","max_tokens":20}' | head -c 300
echo
```{{exec}}

> ```
> {"error":{"message":"The model `does-not-exist` does not exist.","type":"NotFoundError","code":404}}
> ```

**That 404 is better evidence than the 200 was.** A gateway with a broken route returns its own error — a bare `404` from Envoy, or a `503`. This is a *model server's* error message, in the model server's own format. It could only have been produced at the far end of the path, which means the gateway accepted the request, asked the endpoint picker which replica to use, got an answer, and forwarded it there.

When you are wiring this up and something is wrong, that distinction saves a lot of time: an error with a model name in it means the path works and your request is wrong. An error without one means the path is broken.

</details>
