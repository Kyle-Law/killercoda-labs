
Use `helm show values podinfo/podinfo` to find the field that controls replica count. Without changing the chart version, upgrade the `podinfo` release to run **2 replicas** using `--set`. Confirm with `helm get values podinfo` that your override — and only your override — shows up.

<br>

<details><summary>Tip</summary>

```
helm show values podinfo/podinfo | head -5
```{{exec}}

`helm upgrade` is the same command whether you're changing the chart version, the values, or both — here you're only changing values.

</details>

<details><summary>Solution</summary>

```
helm upgrade podinfo podinfo/podinfo --version 6.5.4 --set replicaCount=2
```{{exec}}

```
helm get values podinfo
kubectl get pods -l app.kubernetes.io/name=podinfo
```{{exec}}

</details>
