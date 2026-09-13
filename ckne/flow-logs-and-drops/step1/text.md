
Watch traffic arriving at `api`:

```plain
flows --last 10 --to-pod api
```{{exec}}

Every flow names both ends — and next to each name is a number in brackets. Work out what that number is, then find where Cilium publishes it directly.

Write `api`'s number to `/root/answers/step1.txt`.

<br>

<details><summary>Tip</summary>

The number is the same for every Pod of the same workload, and it does not change when a Pod restarts and gets a new IP. That rules out anything address-shaped.

Cilium assigns one of these to each distinct set of labels. Its endpoint list shows them alongside the labels they were derived from:

```plain
kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg endpoint list
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
flows --last 6 --to-pod api
```{{exec}}

> ```
> default/web-79fbb8dd79-nh6wd:41136 (ID:18586) -> default/api-8b567ddfb-578df:8080 (ID:25203) to-endpoint FORWARDED
> ```

`(ID:25203)` is a **security identity** — Cilium's identifier for *a set of labels*, not for a Pod or an address. Every Pod carrying `app=api` gets the same one.

```plain
kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg endpoint list
```{{exec}}

> ```
> ENDPOINT   POLICY (ingress)   IDENTITY   LABELS              IPv4
> 950        Disabled           25203      k8s:app=api         10.244.0.14
> ```

The identity is derived from the labels, and policy is enforced against the identity. That has a consequence worth holding onto:

```plain
echo 25203 > /root/answers/step1.txt   # use the number YOUR cluster shows
kubectl rollout restart deployment/api
kubectl rollout status deployment/api --timeout=180s
kubectl get pod -l app=api -o jsonpath='{.items[0].status.podIP}{"\n"}'
kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg endpoint list | grep 'app=api'
```{{exec}}

**New Pod, new IP address, same identity.** Policy written against `app=api` never had to be updated, because it was never about the address.

That is the difference between this and an iptables-based view of the world. `iptables` rules reference addresses, so every Pod churn rewrites rules. Cilium resolves labels to an identity once, programs policy against the identity, and a rescheduled Pod inherits it automatically.

> The identity number is local to this cluster and assigned on demand — yours will differ, and the same labels in another cluster get a different number. What is stable is the *mapping from labels to identity*, which is exactly what makes the flow log readable: you see `default/web`, not `10.244.0.37`.

</details>
