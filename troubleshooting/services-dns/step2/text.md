
A Service named `web2-svc` routes to the `web2` Deployment's Pods — its `Endpoints` look correct — but requests through it fail. A Pod named `test-client` is available for testing. Find out why, then fix the Service.

<br>

<details><summary>Tip</summary>

```
kubectl get endpoints web2-svc
kubectl exec test-client -- wget -qO- --timeout=3 web2-svc
```{{exec}}

Endpoints existing just means the *selector* matched. Compare the Service's `targetPort` against the port the container actually listens on:

```
kubectl describe svc web2-svc
kubectl get pods -l app=web2 -o jsonpath='{.items[0].spec.containers[0].ports}'
```{{exec}}

</details>

<details><summary>Solution</summary>

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web2-svc
spec:
  selector:
    app: web2
  ports:
  - port: 80
    targetPort: 80
EOF
```{{exec}}

```
kubectl exec test-client -- wget -qO- --timeout=3 web2-svc
```{{exec}}

</details>
