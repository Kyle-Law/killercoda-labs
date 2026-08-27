
When a rollout of `payments` stalls — a new version that never becomes healthy — `kubectl rollout status` currently waits **10 minutes** (the default) before giving up. In a pipeline, that's 10 minutes of a build hanging before anyone finds out.

Configure `payments` so a stalled rollout is declared failed after **30 seconds** instead. Then prove it works: roll out the image `nginx:this-tag-does-not-exist` and confirm the Deployment itself reports the failure.

<br>

<details><summary>Tip</summary>

```
kubectl explain deployment.spec.progressDeadlineSeconds
```{{exec}}

The failure isn't reported on the Pods — it's a condition on the Deployment:

```
kubectl get deployment payments -o jsonpath='{.status.conditions}'
kubectl describe deployment payments
```{{exec}}

This field isn't part of `spec.template`, so setting it doesn't start a rollout by itself.

</details>

<details><summary>Solution</summary>

```
kubectl patch deployment payments --type merge -p '{"spec":{"progressDeadlineSeconds":30}}'
```{{exec}}

```
kubectl set image deployment/payments nginx=nginx:this-tag-does-not-exist
```{{exec}}

Watch it give up rather than hang — this exits non-zero after about 30 seconds:

```
kubectl rollout status deployment/payments
```{{exec}}

```
kubectl describe deployment payments | grep -A6 Conditions
```{{exec}}

The `Progressing` condition flips to `False` with reason `ProgressDeadlineExceeded`.

</details>
