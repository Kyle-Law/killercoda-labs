
Since the Pod doesn't pick up the new ConfigMap on its own, restart the Deployment manually so the new message takes effect.

<br>

<details><summary>Tip</summary>

```plain
kubectl rollout restart -h
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
kubectl rollout restart deployment mock-app-deployment -n dev-ns
kubectl rollout status deployment mock-app-deployment -n dev-ns
```{{exec}}

```plain
export SERVICE_IP=$(kubectl get svc -n dev-ns mock-app-service -o jsonpath='{.spec.clusterIP}')
curl -s http://${SERVICE_IP}:5000
echo
```{{exec}}

</details>
