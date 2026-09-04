
Now protect `db`: it should accept ingress **only from `api`**, and `db`'s own outbound connections must keep working.

That second requirement sounds like it needs no thought. It does — there is a one-word change that silently kills every outbound connection `db` makes, and the failure won't look like a network policy problem.

Write the policy, then check `matrix` **and** `canreach db web` specifically.

<br>

<details><summary>Tip</summary>

```plain
kubectl explain networkpolicy.spec.policyTypes
```{{exec}}

`policyTypes` declares which directions this policy governs. A direction named there is **denied by default**, and then re-opened only by rules of that kind. So `Egress` in `policyTypes` with no `egress:` rules underneath doesn't mean "don't care about egress" — it means "deny all egress".

If you leave `policyTypes` out entirely, Kubernetes infers it from which rule blocks you wrote. Write only `ingress:` rules and you get `["Ingress"]`:

```plain
kubectl -n shop get netpol -o jsonpath='{range .items[*]}{.metadata.name}{" -> "}{.spec.policyTypes}{"\n"}{end}'
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
kubectl apply -f - <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-allow-api
  namespace: shop
spec:
  podSelector:
    matchLabels:
      app: db
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: api
YAML
```{{exec}}

```plain
matrix
canreach db web
```{{exec}}

`api -> db` allowed, `web -> db` blocked, and `db -> web` still allowed — `db` is protected inbound while its outbound is untouched.

Now see what the one-word change does. Add `Egress` to `policyTypes` without writing a single `egress:` rule:

```plain
kubectl -n shop patch netpol db-allow-api --type merge \
  -p '{"spec":{"policyTypes":["Ingress","Egress"]}}'
sleep 5
canreach db web
canreach db api
```{{exec}}

Both `BLOCKED`. `db` can no longer open a connection to anything — and note that the rules underneath are unchanged; you added a word, not a restriction. Worse, in a real app this surfaces as DNS failures first, because name resolution is itself an outbound connection, so the error you get says nothing about the service you were trying to reach.

Put it back:

```plain
kubectl -n shop patch netpol db-allow-api --type merge \
  -p '{"spec":{"policyTypes":["Ingress"]}}'
sleep 5
matrix
```{{exec}}

> The general rule: **never name a direction in `policyTypes` unless you are also writing the rules for it.** Egress policy is worth doing, but it's a deliberate exercise — allowing DNS, then each destination — not something to switch on in passing.

</details>
