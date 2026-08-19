
The `api` Deployment's container declares a named port called `http` (`containerPort: 80`). Create a Service named `api-svc` that exposes port `80` and targets that Pod port **by name**, not by number.

<br>

<details><summary>Tip</summary>

```
kubectl get deployment api -o yaml | grep -A3 ports
kubectl explain service.spec.ports.targetPort
```{{exec}}

</details>

<details><summary>Solution</summary>

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: api-svc
spec:
  selector:
    app: api
  ports:
  - port: 80
    targetPort: http
EOF
```{{exec}}

```
kubectl get endpoints api-svc
```{{exec}}

</details>
