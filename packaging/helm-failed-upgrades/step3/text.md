
Same broken upgrade one more time, against `podinfo3` (also starts at 2 replicas — keep it there) — `image.tag=6.5.4-does-not-exist` — but swap `--wait` for `--atomic` (keep `--timeout 60s`).

The command still fails after about a minute. But this time check the Pod afterwards: is it broken like the last two releases, or has something put it back the way it was? Then run `helm history podinfo3` — how many revisions does it show, and what does the newest one's description say?

<br>

<details><summary>Tip</summary>

```
helm upgrade --help | grep -B1 -A2 '\-\-atomic'
```{{exec}}

`--atomic` implies `--wait`. The difference is what happens *after* the timeout: `--wait` alone just reports failure and leaves the broken state in place; `--atomic` reacts to that failure by rolling the release back for you.

</details>

<details><summary>Solution</summary>

```
helm upgrade podinfo3 podinfo/podinfo --version 6.5.4 --set replicaCount=2 --set image.tag=6.5.4-does-not-exist --atomic --timeout 60s
```{{exec}}

```
kubectl get pods -l app.kubernetes.io/name=podinfo3
helm history podinfo3
```{{exec}}

The Pod is healthy again on the original `6.5.4` image — three revisions: the original install, the failed upgrade attempt, and a new one whose description mentions a rollback. `--atomic`'s automatic recovery is just `helm rollback` triggered on your behalf; it doesn't erase the failed attempt, it adds one more entry on top of it, same as any rollback.

</details>
