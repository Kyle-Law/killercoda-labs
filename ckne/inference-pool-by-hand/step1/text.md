
Two objects are missing: an `InferencePool` named `llm-pool`, and an `HTTPRoute` named `llm-route` that sends the Gateway's traffic to it.

Everything else already exists. Look at what the picker was told to expect before you write the pool — it will only serve a pool with the name it was given at startup:

```plain
kubectl get deploy llm-epp -o jsonpath='{.spec.template.spec.containers[0].args}'; echo
kubectl get svc llm-epp -o jsonpath='{.spec.ports}'; echo
kubectl get pods -l app=vllm-qwen3-32b --show-labels
```{{exec}}

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

An `InferencePool` needs three things: which Pods it covers (`selector`), which port on those Pods serves traffic (`targetPorts`), and which Service the gateway should ask for a decision (`endpointPickerRef`).

Note what is *not* in that list. There is no Service in front of the model servers — the pool names the Pods directly, and the port is the container's.

The picker exposes three ports. Only one of them is the ext_proc endpoint the gateway calls per request; the other two are health and metrics.

For the route, remember that `backendRefs` defaults to a Service in the core API group, and neither default is right here.

</details>

<details><summary>Solution</summary>

```plain
cat <<EOF | kubectl apply -f -
apiVersion: inference.networking.k8s.io/v1
kind: InferencePool
metadata:
  name: llm-pool
spec:
  selector:
    matchLabels:
      app: vllm-qwen3-32b
  targetPorts:
  - number: 8000
  endpointPickerRef:
    name: llm-epp
    port:
      number: 9002
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
      name: llm-pool
EOF
sleep 15
```{{exec}}

```plain
kubectl get inferencepool llm-pool
poolcall
```{{exec}}

> ```
>   http=200   time=0.087s
>   body: {"id":"cmpl-...","model":"Qwen/Qwen3-32B","usage":{...},"object":"text_completion",...}
> ```

Four things had to agree for that to work, and none of them is checked by anything until traffic flows:

| | must match |
|---|---|
| `selector` | the labels on the model server Pods |
| `targetPorts` | the **container** port, not a Service port |
| `endpointPickerRef.name` | the picker's **Service** |
| `endpointPickerRef.port` | the ext_proc port, `9002` — not health, not metrics |

And a fifth, which is not in the pool at all: the picker was started with `--pool-name llm-pool`. **A picker is bound to one pool by name, from the command line.** Rename the pool and the picker keeps watching for the old one — it will not follow.

> **What the pool replaced.** Without this, routing to three replicas means a Service, and a Service load balances by itself — round-robin over endpoints, knowing nothing about any of them. The pool exists to take that decision away from the datapath and give it to a process that can ask each replica how it is doing. The `endpointPickerRef` is where that swap is declared, and it is the only field in Gateway API that hands routing decisions to something outside the gateway.

</details>
