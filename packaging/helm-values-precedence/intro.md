
<br>

`kiamol/day10-helm` and `packaging/helm-failed-upgrades` both use `--set` exactly once per command. Real installs almost never look like that — they use `-f` values files, layer several of them, and mix in `--set` on top. This lab is about the mechanics of that layering: what wins when sources disagree, what `helm get values` actually shows you, and the handful of `--set` variants (`--set-file`, `--set-string`, list indices) that exist because plain `--set` has sharp edges.

Four independent releases, one lesson each — `podinfo-values1` through `podinfo-values4`.

Every fact in this lab was checked against a live `helm template` render before being written down — including one that turned out to be wrong on modern Helm (a commonly repeated claim that `--set image.tag=1.20` silently corrupts to `1.2`; it doesn't, not on Helm 3.17). Where the lab says something happens, you can prove it yourself with `helm get values`.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
