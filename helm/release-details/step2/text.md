
Use `helm get` to fetch the **values** that were supplied to the `webserver` release, and save them into `/root/values`.

<br>

<details><summary>Info</summary>

By default `helm get values` shows only the values that were *overridden* at install time. Adding `--all` shows the full computed set, chart defaults included — useful when you want to know what a release is really running with.

</details>

<details><summary>Solution</summary>

```plain
helm get values webserver
```{{exec}}

```plain
helm get values webserver > /root/values
```{{exec}}

Compare that with the complete set:

```plain
helm get values webserver --all
```{{exec}}

</details>
