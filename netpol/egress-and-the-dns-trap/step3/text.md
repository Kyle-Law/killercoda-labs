
Finish what step 2 started: add the missing rule, egress from `web` to `api` on port 9898. Confirm `apicall` succeeds.

Then, **without touching `web`'s policy again**, apply a second policy — one that protects `api`, allowing ingress only from some Pod that doesn't exist. Predict what happens to `apicall` before running it.

<br>

<details><summary>Tip</summary>

For the first half: another entry in `web-deny-egress`'s `egress` list, this time `to: [{podSelector: {matchLabels: {app: api}}}]` on `port: 9898`.

For the second half — a policy with `podSelector: {matchLabels: {app: api}}`, `policyTypes: [Ingress]`, and an `ingress.from` naming a label nothing carries, e.g. `app: nothing-has-this-label`. `web`'s egress rule isn't changing; think about what else decides whether a packet arrives.

</details>

<details><summary>Solution</summary>

```plain
kubectl apply -f - <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-deny-egress
  namespace: shop
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    - to:
        - podSelector:
            matchLabels:
              app: api
      ports:
        - protocol: TCP
          port: 9898
YAML
apicall
```{{exec}}

A real response — the outage is over. `web`'s egress side is fully open to `api` now.

```plain
kubectl apply -f - <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-restrict-ingress
  namespace: shop
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: nothing-has-this-label
YAML
apicall
```{{exec}}

`wget: download timed out` — again, with `web`'s egress rule to `api` completely untouched.

Egress from the sender and ingress on the receiver are **two separate evaluations, by two separate policies, and both have to independently say yes.** `web` allowing itself to *send* to `api` says nothing about whether `api` is willing to *receive* from `web` — that's `api`'s own policy's decision alone. Neither side can grant permission on the other's behalf. This is exactly the same independence you'd expect from a real firewall pair, one ruleset per host, and it's why "I opened egress, why is it still blocked" is usually a question about the *other* Pod's ingress policy, not the one you just edited.

```plain
kubectl -n shop delete netpol api-restrict-ingress
apicall
```{{exec}}

</details>
