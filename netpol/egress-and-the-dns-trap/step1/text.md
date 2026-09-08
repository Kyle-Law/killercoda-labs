
`web` calls `api` by name, right now, successfully:

```plain
apicall
```{{exec}}

**Write a policy that denies all egress from `web`** — select it, name `Egress`, write no rules. Then run `apicall` again and read the error carefully. It will not mention a policy.

<br>

<details><summary>Tip</summary>

`spec.podSelector` selects `web`; `spec.policyTypes: [Egress]`; no `egress:` key at all — an absent list, not an empty one, is still "deny everything for this direction".

```plain
apicall
dnscheck
```{{exec}}

Compare the two. One is a name-resolution problem; the other looks like a plain connection failure. Are they actually the same failure, or two different things happening at once?

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
YAML
```{{exec}}

```plain
apicall
```{{exec}}

`wget: bad address 'api:9898'`. Nothing here says "policy" — it reads exactly like a DNS misconfiguration or a typo in the hostname.

```plain
dnscheck
```{{exec}}

`connection timed out; no servers could be reached` — the lookup to CoreDNS itself never got an answer. That confirms the *first* failure: DNS is blocked.

Now check whether that's the *only* problem, by skipping DNS entirely:

```plain
rawcall
```{{exec}}

`wget: download timed out` — a different error, against `api`'s raw ClusterIP, no hostname involved at all. This is not a DNS symptom; it's a straightforwardly blocked connection.

Two separate things broke at once: the lookup to CoreDNS, and the connection to `api` itself. `policyTypes: [Egress]` with no rules denies **every** outbound connection this Pod makes, indiscriminately — DNS is not a special case Kubernetes protects for you. Fixing DNS alone, next, will only fix one of these two failures.

</details>
