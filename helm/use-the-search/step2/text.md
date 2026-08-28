
Install the **second newest** patch version of the `6.5` series of `podinfo/podinfo`, as a release named `podinfo`.

Work out which version that is from the search rather than hardcoding it.

<br>

<details><summary>Tip</summary>

```plain
helm search repo podinfo/podinfo --version '~6.5' -l
```{{exec}}

The listing is ordered newest first, so the second row is the one you want.

</details>

<details><summary>Solution</summary>

```plain
helm search repo podinfo/podinfo --version '~6.5' -l
```{{exec}}

The newest is `6.5.4`, so the second newest is `6.5.3`:

```plain
helm install podinfo podinfo/podinfo --version 6.5.3
```{{exec}}

```plain
helm ls
```{{exec}}

</details>
