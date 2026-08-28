
Delete the Helm release `apiserver`.

<br>

<details><summary>Tip</summary>

```plain
helm uninstall -h
```{{exec}}

Remember it isn't in the `default` Namespace.

</details>

<details><summary>Solution</summary>

```plain
helm ls -A
helm -n team-yellow uninstall apiserver
```{{exec}}

</details>
