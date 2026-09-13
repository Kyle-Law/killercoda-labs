
Every policy so far selected `web` by its **labels**. Try selecting it by its **address** instead — the same permission, written the other way.

Recreate the L4 policy as `api-l4`, but with an `ipBlock` naming `web`'s current Pod IP in place of the `podSelector`. Predict the result before you test it.

<br>

<details><summary>Tip</summary>

```plain
WEBIP=$(kubectl get pod -l app=web -o jsonpath='{.items[0].status.podIP}')
echo "web is at $WEBIP"
```{{exec}}

Delete the L7 policy for this step so nothing else is interfering:

```plain
kubectl delete ciliumnetworkpolicy api-l7
```{{exec}}

Then create `api-l4` with `ipBlock: {cidr: $WEBIP/32}` where the `podSelector` used to be, and run `try GET /hostname`.

</details>

<details><summary>Solution</summary>

```plain
kubectl delete ciliumnetworkpolicy api-l7
WEBIP=$(kubectl get pod -l app=web -o jsonpath='{.items[0].status.podIP}')
echo "web is at $WEBIP"
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
    - ipBlock:
        cidr: ${WEBIP}/32
    ports:
    - protocol: TCP
      port: 8080
EOF
sleep 15
try GET /hostname
```{{exec}}

> ```
> GET /hostname -> 000
> ```

**Blocked — with the correct, current IP address of the very Pod you are calling from.** Nothing is stale; nothing has been rescheduled. The address in the policy is right, and the traffic is refused anyway.

The policy was accepted by the API server, and Cilium translated it faithfully:

```plain
kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg policy get | grep -A3 '"L3"'
```{{exec}}

> `"L3": [ "cidr:10.244.0.12/32" ]`

The rule exists. Now look at why it never fires:

```plain
kubectl -n kube-system exec ds/cilium -c cilium-agent -- \
  hubble observe --since 60s --to-pod api --verdict DROPPED | tail -2
```{{exec}}

> ```
> default/web-...:51544 (ID:18063) <> default/api-...:8080 (ID:5255) policy-verdict:none ... DENIED
> ```

`policy-verdict:none` — **no rule matched**. `web`'s traffic carries its *pod identity* (`ID:18063`), derived from its labels. The rule selects a *CIDR-derived* identity. Those are different identities, so the selector never matches in-cluster Pod traffic, and the rule silently applies to nothing.

Prove the selector is the only variable — rewrite the same policy with a `podSelector` and change nothing else:

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
sleep 15
try GET /hostname
```{{exec}}

> `GET /hostname -> 200`

Same Pod, same IP, same port, same policy name. **Only the selector type differed.**

This is the sharpest possible version of "identity, not address": on an identity-based CNI you cannot express an IP-based allow for in-cluster traffic *at all*. The rule is accepted, stored, shown by `kubectl get netpol`, translated into the datapath — and matches nothing. There is no error, no warning, no event.

And the label-based rule has the property the IP one was reaching for anyway:

```plain
kubectl get pod -l app=web -o jsonpath='{.items[0].status.podIP}{"\n"}'
kubectl rollout restart deployment/web
kubectl rollout status deployment/web --timeout=180s
kubectl get pod -l app=web -o jsonpath='{.items[0].status.podIP}{"\n"}'
try GET /hostname
```{{exec}}

**New Pod, new address, still allowed.** Policy written against labels needs no maintenance when Pods churn, which is the normal state of a cluster.

> `ipBlock` is not useless — it is the right tool for traffic entering from *outside* the cluster, where there is no Pod and therefore no identity to select. Inside the cluster, reach for selectors.

</details>
