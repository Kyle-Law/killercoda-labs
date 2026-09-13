
Express the rule the last step could not: `web` may `GET /hostname` on `api`, and nothing else — same port, same two Pods.

Use a `CiliumNetworkPolicy` named `api-l7`. Apply it **alongside** the `api-l4` policy from step 1, then test all three requests.

It will not do what you expect. Work out why, and make it take effect.

<br>

<details><summary>Tip</summary>

```plain
kubectl explain ciliumnetworkpolicy.spec.ingress.toPorts.rules
```{{exec}}

The shape is the familiar one — `endpointSelector` instead of `podSelector`, `fromEndpoints` instead of `from` — plus a `rules.http` list under `toPorts`, where each entry carries a `method` and a `path`.

When it does not work, do not assume the L7 rule is wrong. Ask what `api-l4` is still saying, and remember that NetworkPolicy is **allow-only and additive**: policies do not restrict each other, they add up.

</details>

<details><summary>Solution</summary>

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
sleep 18
try GET /hostname
try GET /
try POST /hostname
```{{exec}}

> ```
> GET /hostname -> 200
> GET /         -> 200
> POST /hostname -> 200
> ```

**Nothing changed.** And the policy is not being ignored — it is fully programmed:

```plain
apistate
```{{exec}}

> `cilium-http-ingress   153:ingress:TCP:8080:   17914` — the HTTP proxy redirect is active.

So the L7 rule exists, is enforced, and is having no visible effect. The reason is the most important property of this API:

**NetworkPolicy is allow-only and additive. Policies never restrict each other — they union.** `api-l4` says *"`web` may reach `api` on 8080"*, with no conditions. `api-l7` says *"`web` may reach `api` on 8080 when the request is `GET /hostname`"*. A request for `POST /hostname` fails the second rule and satisfies the first — and one match is all it needs.

**A broad L4 allow silently defeats every narrower L7 rule for the same traffic.** Nothing warns you; the L7 policy looks correct, is accepted, and is genuinely loaded.

Remove the broader grant so the L7 rule is the only thing permitting this traffic:

```plain
kubectl delete netpol api-l4
sleep 18
try GET /hostname
try GET /
try POST /hostname
```{{exec}}

> ```
> GET /hostname -> 200
> GET /         -> 403
> POST /hostname -> 403
> ```

Three requests, one port, one pair of Pods, three different treatments — `GET /` refused for its path, `POST /hostname` refused for its method despite the path being the allowed one.

**Now compare that `403` with the `000` from step 1's blocked traffic.** The difference tells you which layer decided:

| Response | What happened |
|---|---|
| `000` / timeout | The packet was **dropped**. Nothing answered, because nothing was allowed to receive it. |
| `403` | Something **answered and refused**. The connection was established, the request read, and a decision made about its contents. |

A `403` proves the request was parsed — which means a component in the path speaks HTTP. That is the subject of the next step, and the thing you are paying for.

> The client also gets an immediate, legible answer instead of hanging until a timeout. That is a real operational gain over an L3/L4 drop: `403` is debuggable; a silent drop is the failure mode the `netpol/` labs spend their time teaching people to recognise.

</details>
