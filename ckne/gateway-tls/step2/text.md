
One listener, one port, one certificate — that's `secure.example.com` handled. Now put a second hostname, `other.example.com`, on the same port 443, terminating with its own certificate and routing to `web-canary` instead of `web`.

Predict first: can one `HTTPS` listener on port 443 serve two different certificates, or does this need a second listener on a different port?

<br>

<details><summary>Tip</summary>

A `Gateway`'s listeners are distinguished by `name`, not by port alone — nothing stops two listeners sharing `port: 443` as long as something else about them differs. What's different here is `hostname`.

Get a second certificate for `other.example.com` the same way you got the first, then add a second `listeners` entry rather than editing the one you have.

</details>

<details><summary>Solution</summary>

```plain
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: other-cert
spec:
  secretName: other-cert-tls
  dnsNames:
  - other.example.com
  issuerRef:
    name: lab-ca-issuer
    kind: ClusterIssuer
EOF
kubectl wait --for=condition=Ready certificate/other-cert --timeout=60s
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
  - name: https-secure
    protocol: HTTPS
    port: 443
    hostname: secure.example.com
    tls:
      mode: Terminate
      certificateRefs:
      - kind: Secret
        name: secure-cert-tls
  - name: https-other
    protocol: HTTPS
    port: 443
    hostname: other.example.com
    tls:
      mode: Terminate
      certificateRefs:
      - kind: Secret
        name: other-cert-tls
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: other-route
spec:
  parentRefs:
  - name: web-gateway
    sectionName: https-other
  hostnames: ["other.example.com"]
  rules:
  - backendRefs:
    - name: web-canary
      port: 80
EOF
```{{exec}}

```plain
echo "--- secure.example.com ---"
servedcert secure.example.com
echo "--- other.example.com ---"
servedcert other.example.com
```{{exec}}

> Two different certificates, two different issuer subjects the same CA signed, two different SANs — from **one IP, one port**. The only thing that told Envoy which certificate to present was the hostname the client asked for before the connection was even encrypted.

That's **SNI** — Server Name Indication, a plaintext field in the TLS `ClientHello` that names the hostname the client is trying to reach, sent *before* any certificate has been exchanged. It's the only way this can work at all: the server has to know which certificate to offer before the handshake can proceed with encrypting anything, so the hostname has to travel unencrypted, this one time, to make that choice possible.

Confirm both routes independently, to the two different backends:

```plain
echo "--- request to secure.example.com ---"
securecurl secure.example.com
echo "--- request to other.example.com ---"
securecurl other.example.com
```{{exec}}

> `web` answers one, `web-canary` answers the other — same as `HTTPRoute` hostname-based routing always worked, just now happening on top of a per-hostname TLS handshake instead of a plaintext one.

</details>
