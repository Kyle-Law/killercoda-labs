
An Ingress controller (`ingress-nginx`) is installed. A Deployment `web` (2 replicas of `nginx`) and its Service `web` already exist. Create an `Ingress` named `web-ingress` that routes requests for host `web.example.com`, path `/`, to the `web` Service on port 80 — using the `nginx` IngressClass.

<br>

<details><summary>Tip</summary>

```
kubectl get ingressclass
kubectl explain ingress.spec
```{{exec}}

There's no real DNS for `web.example.com` here — test with a `Host` header instead:

```
kubectl exec curl-test -- wget -qO- --header="Host: web.example.com" http://ingress-nginx-controller.ingress-nginx.svc.cluster.local
```{{exec}}

</details>

<details><summary>Solution</summary>

```
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: web.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
EOF
```{{exec}}

```
kubectl exec curl-test -- wget -qO- --header="Host: web.example.com" http://ingress-nginx-controller.ingress-nginx.svc.cluster.local
```{{exec}}

</details>
