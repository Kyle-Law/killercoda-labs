
`lab-ca-issuer` is a working `ClusterIssuer`, backed by a root CA `cert-manager` generated for this cluster. Nothing has asked it for a certificate yet.

Get a certificate for `secure.example.com`, then reference it from an HTTPS `Gateway` listener on port 443 and route `web` behind it. Don't take the listener's word for it — confirm with a real TLS handshake that the certificate actually served is the one you asked for.

<br>

<details><summary>Tip</summary>

A `cert-manager` `Certificate` names a Secret to write the result into:

```plain
kubectl explain certificate.spec
```{{exec}}

A `Gateway` listener's `tls.certificateRefs` names that same Secret:

```plain
kubectl explain gateway.spec.listeners.tls
```{{exec}}

`servedcert <sni-name>` does the handshake and prints what came back, with no request involved — just `openssl s_client` plus `openssl x509`. The first time a `Gateway` is created, its Envoy Pod takes a few seconds to start; if the handshake fails, that's most likely why — give it a moment.

</details>

<details><summary>Solution</summary>

```plain
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: secure-cert
spec:
  secretName: secure-cert-tls
  dnsNames:
  - secure.example.com
  issuerRef:
    name: lab-ca-issuer
    kind: ClusterIssuer
EOF
kubectl wait --for=condition=Ready certificate/secure-cert --timeout=60s
```{{exec}}

```plain
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web-gateway
spec:
  gatewayClassName: eg
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    hostname: secure.example.com
    tls:
      mode: Terminate
      certificateRefs:
      - kind: Secret
        name: secure-cert-tls
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: web-route
spec:
  parentRefs:
  - name: web-gateway
  hostnames: ["secure.example.com"]
  rules:
  - backendRefs:
    - name: web
      port: 80
EOF
```{{exec}}

```plain
servedcert secure.example.com
```{{exec}}

> ```
> issuer=CN=lab-root-ca
> X509v3 Subject Alternative Name: critical
>     DNS:secure.example.com
> serial=2D95E8A4330B31339937EA504C1D28D260966352
> ```

That's a real TLS handshake against Envoy's listener returning the exact certificate `cert-manager` issued — not a `kubectl get` reporting a field, a client asking the server to prove it. Finish the loop with an actual request:

```plain
securecurl secure.example.com
```{{exec}}

> `web`'s Pod name, over a connection `curl` verified against the lab's CA (`--cacert /root/ca.crt`) rather than skipping verification. If the wrong certificate had been referenced, or the CA didn't match, this is where it would have failed — a handshake that "succeeds" with `-k`/`--insecure` proves nothing at all.

**The `Certificate` and the `Secret` it produces are the entire interface between `cert-manager` and the `Gateway`.** `cert-manager` doesn't know Envoy exists; the `Gateway` doesn't know `cert-manager` exists. A Secret of type `kubernetes.io/tls`, referenced by name, is the whole contract — which is exactly why any other way of putting a cert/key pair into that Secret (manually, from a different tool entirely) would have worked exactly the same way from the listener's side.

</details>
