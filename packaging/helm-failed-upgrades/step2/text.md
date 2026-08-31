
Run the same broken upgrade against `podinfo2` — `image.tag=6.5.4-does-not-exist` — but this time add `--wait --timeout 60s`.

The command will hang for up to a minute and then **exit with an error** — that's expected, not a mistake. Once it returns, check `helm status podinfo2`. Compare the STATUS to what `podinfo` showed in the last step.

<br>

<details><summary>Tip</summary>

```
helm upgrade --help | grep -B2 -A4 '\-\-timeout'
```{{exec}}

`--wait` blocks until the Deployment is actually available, or the timeout is hit — whichever comes first. A timeout is a real failure, not a slow success.

</details>

<details><summary>Solution</summary>

```
helm upgrade podinfo2 podinfo/podinfo --version 6.5.4 --set image.tag=6.5.4-does-not-exist --wait --timeout 60s
```{{exec}}

The command above exits non-zero after ~60s. That's the point.

```
helm status podinfo2
```{{exec}}

`STATUS: failed` — because this time Helm actually checked, instead of taking the API server's word for it.

</details>
