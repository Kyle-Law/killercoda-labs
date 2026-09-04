
`api` and `db` are protected. `web` still accepts connections from anything in the namespace, because nothing selects it — and any Pod deployed here tomorrow will be wide open too.

Fix that at the namespace level: **every Pod in `shop` should refuse all ingress by default**, including Pods that don't exist yet.

Then answer the question that decides whether policy is usable at all: does `web -> api`, which you allowed in step 1, survive?

<br>

<details><summary>Tip</summary>

`podSelector: {}` — an empty selector — matches **every** Pod in the namespace. It's the idiom for namespace-wide policy.

For a deny-all, you need `policyTypes` to name the direction and then supply no rules for it, which is the shape step 2 warned you about. That shape is a mistake by accident and the correct tool on purpose; the difference is whether you meant it.

Before running `matrix`, decide what you think happens to `web -> api`. There are only two possibilities — a later policy overrides the earlier one, or the two combine — and network policy has no ordering, no priority and no precedence.

</details>

<details><summary>Solution</summary>

```plain
kubectl apply -f - <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: shop
spec:
  podSelector: {}
  policyTypes:
    - Ingress
YAML
```{{exec}}

```plain
matrix
```{{exec}}

`web -> api` and `api -> db` are still `ALLOWED`. Everything else is `BLOCKED`.

Policies **combine as a union of what they allow**. A Pod is evaluated against every policy that selects it, and traffic gets through if *any* of them permits it. The deny-all didn't override anything — it just added a policy with nothing in its allow list, which is why the two specific allows still stand.

This is also why "there is no deny rule" stops being a limitation and becomes the design:

- Adding a policy can only ever **widen** what's permitted for a Pod already covered.
- The *only* thing that restricts a Pod is being selected in the first place.
- So you write one deny-all per namespace to establish the baseline, and then every other policy is purely additive and can be reasoned about on its own. Nothing you add later can silently undo an earlier allow, and no ordering or priority is needed — because nothing ever subtracts.

```plain
kubectl -n shop get netpol
```{{exec}}

Three policies: one that protects everything and permits nothing, and two that each permit one specific path.

</details>
