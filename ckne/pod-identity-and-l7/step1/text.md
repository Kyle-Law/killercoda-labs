
Write a native `NetworkPolicy` named `api-l4` that lets `web` reach `api` on port 8080 and blocks everything else.

Then establish its limit precisely: find a request you would want to refuse that this policy cannot refuse.

<br>

<details><summary>Tip</summary>

```plain
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-l4
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: web
    ports:
    - protocol: TCP
      port: 8080
EOF
sleep 12
```{{exec}}

Then send several different requests over that one allowed port:

```plain
try GET /hostname
try GET /
try POST /
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-l4
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: web
    ports:
    - protocol: TCP
      port: 8080
EOF
sleep 12
try GET /hostname
try GET /
try POST /
```{{exec}}

> ```
> GET /hostname -> 200
> GET /         -> 200
> POST /        -> 200
> ```

The policy is working exactly as written. `web` is allowed to reach `api` on 8080, and **every one of those requests is `web` reaching `api` on 8080.**

```plain
kubectl explain networkpolicy.spec.ingress.from
kubectl explain networkpolicy.spec.ingress.ports
```{{exec}}

> `podSelector`, `namespaceSelector`, `ipBlock` — and `port`, `protocol`, `endPort`.

**There is no field for a method or a path**, in any of it. The API describes which endpoints may exchange packets on which ports. An HTTP method is a string inside the payload of those packets, several layers above anything this API models.

So `POST /` cannot be refused here — not because the policy is written badly, but because the sentence "refuse POST" is not expressible in this vocabulary. The usual workarounds are all outside the network: check the method in the application, put a sidecar in front of it, or accept the risk.

The next step expresses it in the network instead — and finds that adding the new rule is not enough on its own.

</details>
