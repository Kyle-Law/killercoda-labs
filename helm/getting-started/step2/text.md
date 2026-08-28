
Add the `podinfo` chart repository and install the `podinfo/podinfo` chart as a release named `happy-panda`.

<br>

<details><summary>Tip</summary>

```plain
helm repo add -h
helm install -h
```{{exec}}

The repository URL is `https://stefanprodan.github.io/podinfo`.

</details>

<details><summary>Solution</summary>

```plain
helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo update
```{{exec}}

```plain
helm install happy-panda podinfo/podinfo
```{{exec}}

```plain
helm ls
```{{exec}}

</details>
