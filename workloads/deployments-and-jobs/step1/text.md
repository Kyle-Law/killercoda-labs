
Deployment `frontend` is running image `nginx:1.25-alpine`. Update it to `nginx:1.27-alpine` using a proper rolling update — not a delete-and-recreate — and confirm the rollout completes with all 3 replicas ready.

<br>

<details><summary>Tip</summary>

```
kubectl get deployment frontend -o jsonpath='{.spec.template.spec.containers[0].name}'
```{{exec}}

</details>

<details><summary>Solution</summary>

```
kubectl set image deployment/frontend nginx=nginx:1.27-alpine
```{{exec}}

```
kubectl rollout status deployment/frontend
```{{exec}}

</details>
