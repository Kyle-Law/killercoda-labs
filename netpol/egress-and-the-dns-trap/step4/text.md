
`web-deny-egress`'s DNS rule scopes `namespaceSelector` and `podSelector` together, in the same list entry — the AND from step 2's Tip. Find out what the policy would actually permit if that pod-label had been left off, and only the namespace remained.

`kubesystempeer` prints the IP of a real Pod in `kube-system` — one that isn't CoreDNS. Use it with `portcheck <ip> 53` to probe port 53 on it directly, under **both** versions of the rule. Watch the exact wording `portcheck` reports, not just whether it succeeds — one word is the whole answer.

<br>

<details><summary>Tip</summary>

`portcheck` is a thin wrapper around `nc -z`, which distinguishes two outcomes that look similar but mean opposite things for a policy question:

- **"refused"** — the packet arrived, and the destination actively said no one's listening. Network-level, the connection was *allowed through*.
- **"timed out"** — nothing came back at all. Something upstream dropped the packet silently — which is exactly what an enforcing NetworkPolicy does to traffic it denies.

Widen the rule by deleting the `podSelector` under the existing `namespaceSelector`, leaving only the namespace match. Run `portcheck` against `kubesystempeer`'s IP on port 53 both before and after.

</details>

<details><summary>Solution</summary>

First, with the correctly-scoped AND rule already in place from step 2:

```plain
portcheck $(kubesystempeer) 53
```{{exec}}

`timed out`. This Pod was never granted anything — the rule only matches Pods carrying `k8s-app: kube-dns`, and this one doesn't.

Now widen it — drop the pod label, keep only the namespace:

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
portcheck $(kubesystempeer) 53
```{{exec}}

`refused`, not `timed out`. The packet reached this unrelated Pod and was turned away only because nothing happens to be listening on port 53 there — the *network* let it straight through. `namespaceSelector` alone matches **every Pod in `kube-system`**, so this "DNS rule" was quietly also standing open on port 53 toward the API server, etcd, the scheduler, and everything else living in that namespace. Nothing about port 53 makes that safe; it's only safe because nothing else happened to be listening there today.

```plain
dnscheck
```{{exec}}

Still resolves — CoreDNS is, after all, one of the Pods this broader rule matches too. That's what makes the mistake easy to miss: the thing you were testing for keeps working. Put the pod label back:

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
portcheck $(kubesystempeer) 53
```{{exec}}

`timed out` again — the exposure is gone, and `apicall`/`dnscheck` both still work.

</details>
