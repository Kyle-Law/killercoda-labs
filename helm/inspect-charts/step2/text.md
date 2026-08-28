
`helm pull` downloads the chart as a compressed archive so you can open it and explore it with your own tools.

Download the `podinfo/podinfo` chart, **version 6.5.4 specifically**, into `/root/charts/`, and extract it there as well.

<br>

<details><summary>Tip</summary>

```plain
helm pull -h
```{{exec}}

There's a flag that extracts the archive for you, and another that chooses the destination directory.

</details>

<details><summary>Solution</summary>

```plain
mkdir -p /root/charts
helm pull podinfo/podinfo --version 6.5.4 --destination /root/charts --untar
```{{exec}}

```plain
ls /root/charts/podinfo
cat /root/charts/podinfo/Chart.yaml
```{{exec}}

Without `--untar` you'd get `podinfo-6.5.4.tgz` instead, which you could unpack yourself with `tar xzf`.

</details>
