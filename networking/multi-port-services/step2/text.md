
The `multi-api` Deployment exposes two container ports: `http` (80) and `metrics` (9113). Create a Service named `multi-api-svc` that exposes **both** — port `80` and port `9113`.

<br>

<details><summary>Tip</summary>

```
kubectl explain service.spec.ports.name
```{{exec}}

Try it with only one port named and see what the API server says. A Service with more than one port requires every port to have a unique `name`.

</details>

<details><summary>Solution</summary>

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: multi-api-svc
spec:
  selector:
    app: multi-api
  ports:
  - name: http
    port: 80
    targetPort: http
  - name: metrics
    port: 9113
    targetPort: metrics
EOF
```{{exec}}

```
kubectl get svc multi-api-svc -o yaml
```{{exec}}

</details>
