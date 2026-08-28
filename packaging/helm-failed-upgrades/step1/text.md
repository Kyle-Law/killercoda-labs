
`podinfo` is installed and healthy. Upgrade it with `--set image.tag=6.5.4-does-not-exist` — a tag that doesn't exist on the image registry — but **don't** add `--wait`.

The command will return quickly and successfully. Before the Pod has had time to settle, check `helm list` (or `helm status podinfo`): what STATUS does the release show? Now check `kubectl get pods -l app.kubernetes.io/name=podinfo`. Notice the disagreement — Helm considers its job done, the workload does not.

<br>

<details><summary>Tip</summary>

```
helm upgrade --help | grep -A2 '\-\-wait'
```{{exec}}

Without `--wait`, `helm upgrade` only confirms the API server accepted the manifest — it never looks at Pod status. That's true of `helm install` too.

</details>

<details><summary>Solution</summary>

```
helm upgrade podinfo podinfo/podinfo --version 6.5.4 --set image.tag=6.5.4-does-not-exist
```{{exec}}

```
helm status podinfo
kubectl get pods -l app.kubernetes.io/name=podinfo
```{{exec}}

`STATUS: deployed`, and a Pod that's never going to run — `ImagePullBackOff` on a tag that was never going to exist. Helm is not lying, it's just answering a narrower question than "is this working" — it's answering "did the API server accept what I sent it".

</details>
