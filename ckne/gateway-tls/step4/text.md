
Everything so far has been `mode: Terminate` — Envoy decrypts, reads the HTTP request, and re-encrypts nothing on the way to a plaintext backend. There's a second mode. Add a `TLS` listener on port 8443 with `mode: Passthrough`, no certificate, routing to `tls-backend` — a Pod that terminates its own TLS, independently, with its own certificate for `pass.example.com`.

`HTTPRoute` doesn't attach to a `Passthrough` listener. Find out what does, and why `HTTPRoute` specifically can't.

<br>

<details><summary>Tip</summary>

A cert-manager `Certificate` for `pass.example.com` and its Secret already exist — this backend was set up to use them, not to have one handed to it by a `Gateway` listener. Check `tls-backend`'s own config for where its certificate lives.

The `kind` this listener supports is named in its own status once created:

```plain
kubectl get gateway web-gateway -o jsonpath='{.status.listeners[?(@.name=="tls-passthrough")].supportedKinds}'
```{{exec}}

</details>

<details><summary>Solution</summary>

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
  - name: tls-passthrough
    protocol: TLS
    port: 8443
    hostname: pass.example.com
    tls:
      mode: Passthrough
EOF
```{{exec}}

```plain
kubectl get gateway web-gateway -o jsonpath='{.status.listeners[?(@.name=="tls-passthrough")].supportedKinds}'
echo
```{{exec}}

> `[{"group":"gateway.networking.k8s.io","kind":"TLSRoute"}]` — `HTTPRoute` isn't in the list. Not a policy choice you could work around with the right field; the object model itself only offers `TLSRoute` here.

```plain
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TLSRoute
metadata:
  name: pass-route
spec:
  parentRefs:
  - name: web-gateway
    sectionName: tls-passthrough
  hostnames: ["pass.example.com"]
  rules:
  - backendRefs:
    - name: tls-backend
      port: 8443
EOF
```{{exec}}

```plain
servedcert pass.example.com 8443
```{{exec}}

> Still `CN=lab-root-ca`, still the right SAN — but this certificate was never referenced anywhere in the `Gateway` object. It's mounted straight into `tls-backend`'s own Pod, and Envoy has no idea it exists.

The reason `HTTPRoute` can't attach here is mechanical, not arbitrary: **`Passthrough` means Envoy forwards encrypted bytes by SNI alone and never holds the private key needed to decrypt them.** `HTTPRoute` matches on paths, headers, methods — fields that live inside the HTTP request, which in turn lives inside the TLS record. None of that exists yet, from Envoy's side of a passthrough connection. A `TLSRoute` only ever gets to route on what's visible before decryption: the SNI hostname, nothing else. Ask for path-based routing on a passthrough listener and there's no layer left to read it from.

```plain
securecurl pass.example.com 8443
```{{exec}}

Compare what each mode actually cost you: `Terminate` gets Envoy visibility into the request — HTTP-layer routing, and anything else that reads the request, at the price of Envoy holding the private key. `Passthrough` keeps the private key on the backend exclusively — genuinely useful when policy says the platform team must never be able to decrypt this traffic — at the price of every HTTP-aware feature this whole lab has been building.

</details>
