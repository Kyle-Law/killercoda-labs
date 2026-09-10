
`secure-cert-tls` is good for a year, so a genuine renewal won't happen in this lab's lifetime. Force one anyway, and find out what — if anything — has to be told about it.

Note the certificate's serial number, force a reissue, and confirm two things: the Secret really did get new contents, and the `Gateway` is serving them **without you touching the `Gateway` at all**.

<br>

<details><summary>Tip</summary>

```plain
servedcert secure.example.com
```{{exec}}

`cert-manager` reissues whenever the Secret backing a `Certificate` doesn't already hold a matching, unexpired keypair — which includes the case where the Secret doesn't exist.

</details>

<details><summary>Solution</summary>

```plain
echo "before:"
servedcert secure.example.com
```{{exec}}

```plain
kubectl delete secret secure-cert-tls
sleep 5
kubectl get secret secure-cert-tls
```{{exec}}

> A new `secure-cert-tls` exists within seconds — `cert-manager`'s controller noticed the `Certificate` it's responsible for no longer has a backing Secret and reissued immediately.

```plain
echo "after:"
servedcert secure.example.com
```{{exec}}

> Same issuer, same SAN, **different serial**. A new keypair, signed fresh by `lab-ca-issuer`.

No `Gateway`, no `HTTPRoute`, no Envoy Pod was touched — check:

```plain
kubectl get gateway web-gateway -o jsonpath='{.metadata.generation}{"\n"}'
kubectl -n envoy-gateway-system get pods -o jsonpath='{range .items[*]}{.metadata.name}{" restarts="}{.status.containerStatuses[0].restartCount}{"\n"}{end}'
```{{exec}}

**Envoy Gateway watches the Secret a listener's `certificateRefs` points to, not a specific version of it.** The moment the content changes, it's picked up — reissuance, manual edit, anything. That's what makes this work as automation rather than a manual step: the whole renewal is `cert-manager` replacing a Secret's contents, and every consumer of that Secret finds out for free because Kubernetes already tells them when a mounted or referenced object changes.

> A production `Certificate` is left to renew on its own schedule — `cert-manager` starts trying at two-thirds of the certificate's lifetime by default (`spec.duration` and `spec.renewBefore` control both ends). Deleting the Secret is a shortcut for *this lab*, to see the mechanism without waiting a year; it isn't how renewal happens in practice, only a fast, honest way to trigger the same reissuance path.

</details>
