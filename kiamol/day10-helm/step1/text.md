
Add the `podinfo` chart repository (`https://stefanprodan.github.io/podinfo`) as a repo named `podinfo`, update your local repo index, then install it as a release named `podinfo` — but pin the chart to **exactly version `6.5.4`**, not whatever's latest. Confirm it's `deployed` and the Pod is Ready.

<br>

<details><summary>Tip</summary>

```
helm repo add --help
helm search repo podinfo --versions
```{{exec}}

`helm install` takes a `--version` flag matching a chart version, not an app/image version.

</details>

<details><summary>Solution</summary>

```
helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo update
```{{exec}}

```
helm search repo podinfo --versions | head
```{{exec}}

```
helm install podinfo podinfo/podinfo --version 6.5.4
```{{exec}}

```
helm list
kubectl get pods -l app.kubernetes.io/name=podinfo
```{{exec}}

</details>
