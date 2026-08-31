
`podinfo-values3` is at revision 2, with `replicaCount: 2` set via `--set`. Compare `helm get values podinfo-values3` against `helm get values podinfo-values3 -a` — the second one shows a lot more. What is it showing that the first one doesn't?

Now upgrade again, adding `--set logLevel=debug`. If you did this the way `day10-helm` warned about, the replica override from the last step would silently drop back to the chart's default of 1 — fix that: add the flag that makes this upgrade start from the release's **current** values instead of the chart's defaults, so both overrides survive together.

Confirm `helm get values podinfo-values3` shows **both** `replicaCount: 2` and `logLevel: debug`, and that the Deployment is still on 2 replicas.

<br>

<details><summary>Tip</summary>

```
helm upgrade --help | grep -B1 -A2 '\-\-reuse-values'
```{{exec}}

`-a` on `helm get values` adds the chart's own defaults into the output — it's the same tree Helm actually renders with, not just what you supplied.

</details>

<details><summary>Solution</summary>

```
helm get values podinfo-values3
helm get values podinfo-values3 -a
```{{exec}}

The plain view: just `replicaCount: 2`, your one override. The `-a` view: the entire values tree the chart renders with — `image`, `resources`, `service`, everything — your override merged into the chart's own defaults.

```
helm upgrade podinfo-values3 podinfo/podinfo --version 6.5.4 --set logLevel=debug --reuse-values
```{{exec}}

```
helm get values podinfo-values3
kubectl get deployment podinfo-values3
```{{exec}}

Both overrides present, 2 replicas intact. `--reuse-values` is the fix for the footgun `day10-helm` only warned about — without it, this exact command would have quietly reset `replicaCount` back to 1.

</details>
