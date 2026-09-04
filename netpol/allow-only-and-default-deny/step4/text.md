
A new component arrives. It scrapes `api`, and nothing should ever connect *to* it:

```plain
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: metrics
  namespace: shop
spec:
  replicas: 1
  selector:
    matchLabels:
      app: metrics
  template:
    metadata:
      labels:
        app: metrics
    spec:
      containers:
      - name: app
        image: stefanprodan/podinfo:6.6.0
        env:
        - name: PODINFO_UI_MESSAGE
          value: "metrics"
        ports:
        - containerPort: 9898
---
apiVersion: v1
kind: Service
metadata:
  name: metrics
  namespace: shop
spec:
  selector:
    app: metrics
  ports:
  - port: 9898
    targetPort: 9898
YAML
kubectl -n shop rollout status deployment/metrics --timeout=120s
matrix
```{{exec}}

Two things to establish. First, how much work did you have to do to make `metrics` refuse inbound connections? Second: **let `metrics` reach `api`, and nothing else.**

Think about where that second policy goes before you write it.

<br>

<details><summary>Tip</summary>

The thing you are permitting is *inbound traffic to `api`*. Policy protects the **destination**, so a rule about who may talk to `api` belongs to a policy that selects `api` — writing a policy that selects `metrics` would govern what reaches `metrics`, which is the opposite of what you want.

You can either extend the existing `api-allow-web` policy's `from` list, or add a second policy that also selects `api`. Both work, because policies are a union — step 3 established that.

```plain
kubectl -n shop get netpol api-allow-web -o yaml
```{{exec}}

</details>

<details><summary>Solution</summary>

`metrics` was protected the moment it started, and you did nothing. The `default-deny-ingress` policy selects `podSelector: {}` — every Pod in the namespace, including every Pod created after the policy was written. That's the payoff for setting the baseline at the namespace level rather than per app.

Now permit the one path, by adding a second source to the policy that protects `api`:

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
        - podSelector:
            matchLabels:
              app: metrics
YAML
sleep 5
matrix
```{{exec}}

The finished namespace: `web -> api`, `api -> db` and `metrics -> api` allowed; all twelve other directions blocked, including everything pointed at `metrics`.

Four policies, and every one of them is readable on its own:

```plain
kubectl -n shop get netpol
```{{exec}}

- `default-deny-ingress` — selects everything, permits nothing. The baseline.
- `api-allow-web` — the two sources allowed to reach `api`.
- `db-allow-api` — the one source allowed to reach `db`.

Nothing has to be read in order, nothing overrides anything, and adding a fourth allow tomorrow cannot silently break the three that exist. That property is what you buy by giving up deny rules.

> Those two `podSelector` entries under `from` are separate list items, which means **OR** — `web` or `metrics`. Combining selectors inside a *single* list item means AND instead, and getting that distinction backwards is the most common way a policy ends up far more permissive than intended. That's its own subject.

</details>
