
Fix the DNS half. Allow `web` egress to CoreDNS — UDP **and** TCP, port 53 — scoped to the `kube-dns` Pods specifically, not the whole `kube-system` namespace. (Why not just the namespace: step 4.)

Predict what happens to `apicall` once DNS works again. It is not what most people expect the first time.

<br>

<details><summary>Tip</summary>

CoreDNS's Pods carry the label `k8s-app: kube-dns`. To scope by namespace **and** pod label together — "the kube-dns Pods, in the kube-system namespace" — both selectors go as fields of the **same** `to` list entry. As two separate entries, it becomes "any pod in kube-system, or any kube-dns-labeled pod anywhere" — far broader, and the subject of step 4.

Every namespace carries an immutable label since Kubernetes 1.21: `kubernetes.io/metadata.name`, always equal to the namespace's own name. It's a steadier anchor than hoping someone remembered to hand-label `kube-system` with something custom.

Why both protocols: DNS answers that don't fit in one UDP packet retry automatically over TCP. Allow UDP only and everything looks fine until a response happens to be large.

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
YAML
```{{exec}}

```plain
dnscheck
```{{exec}}

Resolves cleanly now — a real address, no errors.

```plain
apicall
```{{exec}}

Still `wget: download timed out`. **DNS was necessary, not sufficient.** `web` can now find out what `api`'s address is; it still can't open a connection to it, because nothing has allowed egress from `web` to `api` on port 9898 — that's a separate rule this policy doesn't have yet.

This is the trap in full: fixing DNS makes the symptom *change* — from an immediate, obviously-DNS-shaped failure to a plain connection timeout — without fixing the outage. Someone watching only the error message can spend real time convinced they've made progress.

</details>
