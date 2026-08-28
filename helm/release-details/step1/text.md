
A release is already installed in the `default` namespace.

Use `helm get` to fetch the **notes** of that release, and save them into `/root/notes`.

[What are the Helm notes?](https://helm.sh/docs/chart_template_guide/notes_files/)

<br>

<details><summary>Tip</summary>

```plain
helm ls
helm get -h
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
helm get notes webserver
```{{exec}}

```plain
helm get notes webserver > /root/notes
```{{exec}}

</details>
