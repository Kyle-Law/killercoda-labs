
Nothing is restricted yet:

```plain
matrix
```{{exec}}

Six directions, all `ALLOWED`. That's not a setting anyone chose — it's what a Pod that no policy selects does.

**Write one NetworkPolicy in the `shop` namespace that allows `web` to reach `api`.** Just that: select `api`, allow ingress from `web`. Don't write anything about `db`, and don't write a second policy.

Before running `matrix` again, write down all six predictions. The interesting cells are `db -> api` and `web -> db`.

<br>

<details><summary>Tip</summary>

The three parts that matter are `spec.podSelector` (which Pods this policy *applies to*), `spec.policyTypes` (which directions it governs), and `spec.ingress[].from` (what's allowed in).

`podSelector` selects the Pods being **protected**, not the Pods being permitted. The permitted side goes under `from`.

```plain
kubectl explain networkpolicy.spec.podSelector
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
kubectl apply -f - <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-allow-web
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
              app: web
YAML
```{{exec}}

```plain
matrix
```{{exec}}

Exactly one cell changed: `db -> api` is now `BLOCKED`. Everything else is still `ALLOWED`, including `web -> db` and `api -> db`.

Read that carefully, because it's the whole model:

- The policy never mentioned `db`, and did not block anything. It **selected `api`**, which switched `api` from "accepts everything" to "accepts nothing", and then allowed `web` back in.
- `db` and `web` are selected by no policy at all, so they still accept everything from anyone. Tightening `api` did nothing whatsoever for its neighbours.

That second point is the one that bites in production: a namespace can be covered in policies and still have Pods that accept traffic from anywhere, simply because no policy happens to select them. Coverage is per-Pod, and silence means open.

</details>
