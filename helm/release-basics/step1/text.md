
Write the list of **all** Helm releases in the cluster into `/root/releases`.

<br>

<details><summary>Info</summary>

```plain
Helm Chart:   Kubernetes YAML template files combined into a single package; Values allow customisation
Helm Release: An installed instance of a Chart
Helm Values:  Customise the YAML template files in a Chart when creating a Release
```

</details>

<details><summary>Tip 1</summary>

```plain
helm ls
```{{exec}}

</details>

<details><summary>Tip 2</summary>

```plain
helm ls -A
```{{exec}}

</details>

<details><summary>Solution</summary>

Helm releases can be installed into any *Namespace*, so here we have to look in all of them.

```plain
helm ls -A > /root/releases
```{{exec}}

</details>
