
Two ready-made files are sitting in `/root`: `base-values.yaml` and `override-values.yaml`. Look at both — they disagree on both fields.

Before running anything, predict the outcome of:

```
helm upgrade podinfo-values2 podinfo/podinfo --version 6.5.4 -f base-values.yaml -f override-values.yaml --set replicaCount=5
```

Which `replicaCount` wins? Which `ui.message` wins? Run it, then check `helm get values podinfo-values2` against your prediction.

Now **swap the order of the two `-f` flags** and re-run the upgrade (keep the same `--set`). Does `replicaCount` change? Does `ui.message`? Leave the release in this swapped-order state.

<br>

<details><summary>Tip</summary>

```
cat /root/base-values.yaml /root/override-values.yaml
```{{exec}}

Multiple `-f` flags merge left to right, like layers — the rightmost file wins wherever two files disagree. `--set` sits above all of them regardless of where it appears on the command line.

</details>

<details><summary>Solution</summary>

```
helm upgrade podinfo-values2 podinfo/podinfo --version 6.5.4 -f /root/base-values.yaml -f /root/override-values.yaml --set replicaCount=5
helm get values podinfo-values2
```{{exec}}

`replicaCount: 5` (the `--set` — it beats every file, no matter where it's positioned). `message: from override` (the rightmost `-f`).

```
helm upgrade podinfo-values2 podinfo/podinfo --version 6.5.4 -f /root/override-values.yaml -f /root/base-values.yaml --set replicaCount=5
helm get values podinfo-values2
```{{exec}}

`replicaCount` is still `5` — `--set` didn't move. `message` flips to `from base`, because `base-values.yaml` is now the rightmost file.

</details>
