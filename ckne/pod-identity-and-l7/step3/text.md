
Something in the path parsed that HTTP request and returned a `403`. Find it, and measure what it costs.

<br>

<details><summary>Tip</summary>

```plain
apistate
```{{exec}}

That prints Cilium's view of the `api` endpoint and any proxy redirects it has programmed. Compare what it shows now against what it would show with no L7 policy — you can delete `api-l7` and re-run it.

`latency 40` measures mean and median over 40 requests. Measure with the policy and without.

</details>

<details><summary>Solution</summary>

```plain
apistate
```{{exec}}

> ```
> === api endpoint ===
> ENDPOINT   POLICY (ingress)   IDENTITY   LABELS         IPv4
> 2119       Enabled            5255       k8s:app=api    10.244.0.128
>
> === proxy redirects ===
> Proxy Status:   OK, ip 10.244.0.244, 1 redirects active on ports 10000-20000
>   Protocol              Redirect                 Proxy Port
>   cilium-http-ingress   2119:ingress:TCP:8080:   17914
> ```

`cilium-http-ingress   2119:ingress:TCP:8080:` — traffic arriving at endpoint `2119` on TCP 8080 is **redirected into an HTTP proxy** listening on port 17914. That proxy is Envoy, running as the `cilium-envoy` DaemonSet:

```plain
kubectl -n kube-system get ds cilium-envoy
```{{exec}}

So the request path changed shape. Without an L7 rule, a packet is matched against an eBPF policy map in the kernel and forwarded — the decision costs a map lookup. With one, the connection is terminated by Envoy, the HTTP request is parsed, matched against your rule, and then proxied onward.

Measure it:

```plain
echo "--- with the L7 proxy in the path ---"
latency 40
kubectl delete ciliumnetworkpolicy api-l7
sleep 15
echo "--- eBPF only, no L7 rule ---"
latency 40
```{{exec}}

> ```
> --- with the L7 proxy in the path ---
>   40 requests: mean 0.0009s  median 0.0008s
> --- eBPF only, no L7 rule ---
>   40 requests: mean 0.0005s  median 0.0005s
> ```

**Roughly a 1.5–2× increase in per-request latency**, on the order of a few hundred microseconds here. Be careful how you read that: the absolute number is tiny because both Pods are on one node with no real network between them, and a real path has milliseconds of genuine network latency that this overhead disappears into. The number that generalises is the *shape* — a userspace round trip per request, paid on every request matching the rule.

That cost buys three things worth having: a decision the kernel could not make, a `403` instead of a silent drop, and an HTTP-aware flow log. It is worth paying where you need it and worth scoping tightly where you do not — an L7 rule matching more traffic than intended puts the proxy in front of all of it.

```plain
cat <<EOF | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: api-l7
spec:
  endpointSelector:
    matchLabels:
      app: api
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: web
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
      rules:
        http:
        - method: GET
          path: /hostname
EOF
sleep 15
try GET /hostname
```{{exec}}

</details>
