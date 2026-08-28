
Install the Helm chart `podinfo/podinfo` into *Namespace* `team-yellow`.

The release should have the name `devserver`.

<br>

<details><summary>Tip</summary>

```plain
helm install -h
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
helm -n team-yellow install devserver podinfo/podinfo
```{{exec}}

</details>
