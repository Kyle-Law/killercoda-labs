
You don't need to download a chart to check something quick — `helm show` reads it straight from the repository.

Explore `nginx-stable/nginx-ingress` with it, then save the chart's **default values** into `/root/values.yaml`.

<br>

<details><summary>Tip</summary>

```plain
helm show -h
```{{exec}}

`helm show` has subcommands for `values`, `chart`, `readme`, `crds`, and `all`. Version-pin any of them with `--version`.

</details>

<details><summary>Solution</summary>

```plain
helm show chart nginx-stable/nginx-ingress
```{{exec}}

```plain
helm show readme nginx-stable/nginx-ingress
```{{exec}}

```plain
helm show values nginx-stable/nginx-ingress
```{{exec}}

```plain
helm show values nginx-stable/nginx-ingress > /root/values.yaml
```{{exec}}

</details>
