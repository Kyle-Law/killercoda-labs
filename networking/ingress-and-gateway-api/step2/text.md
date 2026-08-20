
Gateway API CRDs are installed. Recreate `web-ingress`'s routing intent using Gateway API instead:

- a `GatewayClass` named `nginx-gwc` with `controllerName: k8s.io/ingress-nginx`
- a `Gateway` named `web-gateway` using that class, listening on port 80 (protocol `HTTP`)
- an `HTTPRoute` named `web-route`, attached to `web-gateway`, matching hostname `web.example.com`, routing to the `web` Service on port 80

<br>

> No controller in this cluster actually reconciles these objects into live traffic — `ingress-nginx` here only speaks classic Ingress. This step checks that the object graph itself is wired correctly: the shape you'd need regardless of which Gateway API implementation eventually reads it.

<details><summary>Tip</summary>

```
kubectl get gatewayclass,gateway,httproute -A
kubectl explain gateway.spec
kubectl explain httproute.spec
```{{exec}}

</details>

<details><summary>Solution</summary>

```
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: nginx-gwc
spec:
  controllerName: k8s.io/ingress-nginx
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web-gateway
spec:
  gatewayClassName: nginx-gwc
  listeners:
  - name: http
    protocol: HTTP
    port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: web-route
spec:
  parentRefs:
  - name: web-gateway
  hostnames:
  - "web.example.com"
  rules:
  - backendRefs:
    - name: web
      port: 80
EOF
```{{exec}}

```
kubectl get gatewayclass,gateway,httproute
```{{exec}}

</details>
