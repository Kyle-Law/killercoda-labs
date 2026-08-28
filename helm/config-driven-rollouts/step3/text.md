
The upgrade worked — but did anything actually change?

<br>

<details><summary>Check the ConfigMap</summary>

```plain
kubectl get cm -n dev-ns mock-app-configmap -o jsonpath='{.data}'
echo
```{{exec}}

Updated, as expected.

</details>

<details><summary>Check what the container serves</summary>

```plain
export SERVICE_IP=$(kubectl get svc -n dev-ns mock-app-service -o jsonpath='{.spec.clusterIP}')
curl -s http://${SERVICE_IP}:5000
echo
```{{exec}}

Still the **old** message.

</details>

<details><summary>Check whether the Pod was replaced</summary>

```plain
kubectl get pods -n dev-ns
```{{exec}}

Same Pod, same age — it was never restarted.

</details>

<br>

**Why:** environment variables are injected when the container starts. Updating the ConfigMap has no effect on a process that's already running, and Helm had no reason to restart anything — the Deployment's Pod template didn't change, only a separate ConfigMap object did. Kubernetes only rolls a Deployment when its **Pod template** changes.

There's no verification on this step — continue when you've seen the mismatch.
