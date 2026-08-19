
A Service named `backend-svc` in the `default` namespace should route traffic to the `backend` Deployment's Pods, but it has no working endpoints. Find out why, then fix the Service so it routes traffic correctly.

<br>

<details><summary>Tip</summary>

```
kubectl get endpoints backend-svc
kubectl get pods --show-labels
kubectl describe service backend-svc
```{{exec}}

Compare the Service's `Selector` against the actual Pod labels.

</details>

<details><summary>Solution</summary>

A Service's spec, unlike most Pod fields, is fully mutable — reapplying a corrected manifest is enough:

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
spec:
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 80
EOF
```{{exec}}

```
kubectl get endpoints backend-svc
```{{exec}}

</details>
