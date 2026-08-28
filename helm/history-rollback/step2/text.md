
The upgrade succeeded as far as Helm is concerned, but the Pods are failing — so something in the values of the newest revision is wrong.

Compare the values of the current revision against the previous ones to find the last good revision, then save **that revision's** values into `/root/values`.

<br>

<details><summary>Tip</summary>

```plain
helm get values -h
```{{exec}}

`helm get` can read any revision, not just the current one — there's a flag for it.

</details>

<details><summary>Solution</summary>

```plain
helm get values webserver
```{{exec}}

That's the broken one — note the `image.tag` override. Now look back:

```plain
helm get values webserver --revision 2
helm get values webserver --revision 1
```{{exec}}

Revision 2 is the newest one without the bad `image.tag`:

```plain
helm get values webserver --revision 2 > /root/values
```{{exec}}

</details>
