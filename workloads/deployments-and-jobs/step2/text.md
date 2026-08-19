
A new rollout of `frontend` was started but it's stuck — `kubectl rollout status` won't complete. Investigate, then roll back to the last working revision.

<br>

<details><summary>Tip</summary>

```
kubectl rollout status deployment/frontend --timeout=5s
kubectl rollout history deployment/frontend
kubectl get pods -l app=frontend
```{{exec}}

</details>

<details><summary>Solution</summary>

```
kubectl rollout undo deployment/frontend
```{{exec}}

```
kubectl rollout status deployment/frontend
```{{exec}}

</details>
