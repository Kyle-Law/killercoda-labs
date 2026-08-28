
Use `helm get` to fetch the **manifest** of the `webserver` release — the fully rendered Kubernetes YAML that Helm actually applied — and save it into `/root/manifest`.

<br>

<details><summary>Solution</summary>

```plain
helm get manifest webserver
```{{exec}}

```plain
helm get manifest webserver > /root/manifest
```{{exec}}

</details>
