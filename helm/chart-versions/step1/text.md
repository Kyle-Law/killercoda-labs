
By default `helm search repo` shows only the **newest** version of a chart.

Use it to find **all** patch versions of `podinfo/podinfo` in the `6.5` minor series, and save that listing into `/root/releases`.

<br>

<details><summary>Info</summary>

```plain
Version constraints understand ranges, not just exact versions:
  --version '~6.5'    any 6.5.x
  --version '^6.5'    any 6.x  (>= 6.5)
  --version '6.5.4'   exactly that one
```

</details>

<details><summary>Tip</summary>

```plain
helm search repo -h
```{{exec}}

One flag switches from "newest only" to "every version".

</details>

<details><summary>Solution</summary>

```plain
helm search repo podinfo/podinfo --version '~6.5' -l
```{{exec}}

```plain
helm search repo podinfo/podinfo --version '~6.5' -l > /root/releases
```{{exec}}

</details>
