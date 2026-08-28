
Now prove the annotation works. Upgrade the release so the message becomes:

```plain
You successfully automated the rollout!
```

This time **do not** restart anything by hand — the rollout should happen on its own.

<br>

<details><summary>Solution</summary>

```plain
helm -n dev-ns upgrade mock-app /charts/mock-app --set message="You successfully automated the rollout!"
```{{exec}}

Watch the Deployment roll without any manual intervention:

```plain
kubectl rollout status deployment mock-app-deployment -n dev-ns
kubectl get pods -n dev-ns
```{{exec}}

```plain
export SERVICE_IP=$(kubectl get svc -n dev-ns mock-app-service -o jsonpath='{.spec.clusterIP}')
curl -s http://${SERVICE_IP}:5000
echo
```{{exec}}

The new message is served without a single `kubectl rollout restart`.

</details>

<details><summary>Check the annotation actually changed</summary>

```plain
kubectl get deployment mock-app-deployment -n dev-ns -o jsonpath='{.spec.template.metadata.annotations}'
echo
```{{exec}}

That hash is what changed the Pod template and triggered the rollout.

</details>
