
`team-b` has its own `web` Deployment and Service, entirely separate from yours. Make `team-b.example.com`, on the `public` listener, route to `team-b`'s `web` — using an `HTTPRoute` you create **in the `default` namespace**, with a `backendRef` that crosses into `team-b`.

Expect it to fail the first time. Read exactly why, and fix only that.

<br>

<details><summary>Tip</summary>

```plain
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: cross-ns-route
spec:
  parentRefs:
  - name: web-gateway
    sectionName: public
  hostnames: ["team-b.example.com"]
  rules:
  - backendRefs:
    - name: web
      namespace: team-b
      port: 80
EOF
```{{exec}}

```plain
kubectl get httproute cross-ns-route -o jsonpath='{range .status.parents[0].conditions[?(@.type=="ResolvedRefs")]}status: {.status}{"\n"}reason: {.reason}{"\n"}message: {.message}{"\n"}{end}'
```{{exec}}

The condition names the exact object type that's missing, and which namespace it has to live in.

</details>

<details><summary>Solution</summary>

```plain
kubectl get httproute cross-ns-route -o jsonpath='{range .status.parents[0].conditions[?(@.type=="ResolvedRefs")]}status: {.status}{"\n"}reason: {.reason}{"\n"}message: {.message}{"\n"}{end}'
```{{exec}}

> ```
> status: False
> reason: RefNotPermitted
> message: Backend ref to Service team-b/web not permitted by any ReferenceGrant.
> ```

`Accepted` was `True` — the Gateway happily took the route. It's specifically the **reference to a Service in another namespace** that got refused, and refused *silently* at the traffic layer: no admission error, `kubectl apply` succeeds, and a request just gets a `500` with nothing in the response explaining why.

```plain
GWIP=$(gwaddr)
kubectl exec client -- wget -qO- -T5 --header="Host: team-b.example.com" "http://$GWIP:80/hostname"; echo
```{{exec}}

> `500 Internal Server Error`. Envoy accepted the route, has nowhere it's allowed to actually send the request, and that's the result.

`ReferenceGrant` is what team-b has to create, in *their own* namespace, to opt in to being targeted:

```plain
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-default-httproutes
  namespace: team-b
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: default
  to:
  - group: ""
    kind: Service
    name: web
EOF
```{{exec}}

```plain
sleep 5
kubectl exec client -- wget -qO- -T5 --header="Host: team-b.example.com" "http://$GWIP:80/hostname"; echo
```{{exec}}

> `team-b`'s Pod name. Nothing about `cross-ns-route` changed — the grant alone was the missing piece.

Read the shape of that `ReferenceGrant` carefully, because it's inverted from what people expect: it lives in `team-b`, the namespace being pointed *at*, and it names `default` — the namespace the reference is coming *from* — not the other way around. **The team that owns the target decides who's allowed to send it traffic, not the team writing the route.** That's deliberate: an `HTTPRoute` in a namespace you don't control could otherwise silently redirect traffic into any Service in your namespace, with no way for you to know until it happened.

<br>

<details><summary>Info: this is a different boundary from the one in step 1</summary>

Step 1's `sectionName` chose *which listener* a route attaches to. There's a second, separate control over *which namespaces may attach routes to a Gateway at all* — the listener's own `allowedRoutes`, which defaults to same-namespace-only. See it fail on its own terms:

```plain
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: team-b-native-route
  namespace: team-b
spec:
  parentRefs:
  - name: web-gateway
    namespace: default
    sectionName: public
  hostnames: ["team-b-native.example.com"]
  rules:
  - backendRefs:
    - name: web
      port: 80
EOF
sleep 5
kubectl -n team-b get httproute team-b-native-route -o jsonpath='{range .status.parents[0].conditions[?(@.type=="Accepted")]}status: {.status}{"\n"}reason: {.reason}{"\n"}{end}'
```{{exec}}

> `reason: NotAllowedByListeners` — rejected before `ResolvedRefs` is even evaluated, and for a completely different reason than the one above: nothing to do with the backend, everything to do with which namespace the *route itself* is sitting in.

Two boundaries, enforced by two different objects, at two different points in the pipeline: `allowedRoutes` on the listener decides whose **routes** may attach at all; `ReferenceGrant` decides whose **backends** an already-attached route may point at. `cross-ns-route` only had to clear the second one, because it lived in `default` — the same namespace as the Gateway — the whole time.

```plain
kubectl -n team-b delete httproute team-b-native-route
```{{exec}}

</details>

</details>
