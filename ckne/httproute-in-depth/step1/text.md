
`web`, `web-canary`, and a `GatewayClass` named `eg` all exist. Nothing routes to any of them yet.

Create a `Gateway` named `web-gateway` using that class, with **two** listeners: `public` on port 80 and `internal` on port 8080, both plain `HTTP`.

Then attach an `HTTPRoute` named `web-route` for hostname `web.example.com`, routing to `web` — but only to the **public** listener. Confirm it works on port 80, and confirm it does **not** work on port 8080, on the same Gateway, for the same hostname.

<br>

<details><summary>Tip</summary>

Two listeners means two entries in `spec.listeners`, each with its own `name`.

An `HTTPRoute`'s `parentRefs` doesn't have to mean "every listener this Gateway has." Look at `sectionName`:

```plain
kubectl explain httproute.spec.parentRefs.sectionName
```{{exec}}

`gwaddr` prints the Envoy Service's ClusterIP once the Gateway exists. Test both ports against it, same `Host` header both times:

```plain
GWIP=$(gwaddr)
kubectl exec client -- wget -qO- -T5 --header="Host: web.example.com" "http://$GWIP:80/hostname"; echo
kubectl exec client -- wget -qO- -T5 --header="Host: web.example.com" "http://$GWIP:8080/hostname"; echo
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
  - name: public
    protocol: HTTP
    port: 80
  - name: internal
    protocol: HTTP
    port: 8080
EOF
```{{exec}}

```plain
kubectl get gateway web-gateway
```{{exec}}

> `PROGRAMMED` is `False`. Ignore it for now — it's reporting that no *external* address was assigned, which is expected without a cloud load balancer. Look one level down instead:

```plain
kubectl get gateway web-gateway -o jsonpath='{range .status.listeners[*]}{.name}: Programmed={.conditions[?(@.type=="Programmed")].status}{"\n"}{end}'
```{{exec}}

> Both listeners say `Programmed=True`. **That's the condition that means "traffic will actually flow" — the top-level `PROGRAMMED` is specifically about a routable external address, a separate concern this cluster has no way to satisfy.** Reading the wrong condition here is an easy way to conclude a working Gateway is broken.

Now attach a route to exactly one of the two:

```plain
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: web-route
spec:
  parentRefs:
  - name: web-gateway
    sectionName: public
  hostnames: ["web.example.com"]
  rules:
  - backendRefs:
    - name: web
      port: 80
EOF
```{{exec}}

```plain
GWIP=$(gwaddr)
echo "--- port 80 (public, has the route) ---"
kubectl exec client -- wget -qO- -T5 --header="Host: web.example.com" "http://$GWIP:80/hostname"; echo
echo "--- port 8080 (internal, no route) ---"
kubectl exec client -- wget -qO- -T5 --header="Host: web.example.com" "http://$GWIP:8080/hostname"; echo
```{{exec}}

> Port 80 answers with `web`'s Pod name. Port 8080 answers `404`. Same Gateway, same hostname, same backend available either way — the only difference is which listener `sectionName` named.

One Envoy Service is fronting both ports:

```plain
kubectl -n envoy-gateway-system get svc -l gateway.envoyproxy.io/owning-gateway-name=web-gateway
```{{exec}}

**A `Gateway` is infrastructure — who's allowed to plug in, on which ports, for which hostnames. An `HTTPRoute` is one team's routing intent, opted into a specific plug.** This is the split Ingress never had: a platform team owns and provisions the `Gateway`, and separate `HTTPRoute`s — potentially from separate teams, separate namespaces — attach to whichever listener they're entitled to, without needing write access to the Gateway itself or visibility into what else is attached to it.

</details>
