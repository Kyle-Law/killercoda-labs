
Upgrade `podinfo` again — this time bump `logLevel` to `debug` via `--set`, creating revision 3.

Then roll back to revision 1 (the original install, no overrides at all). Confirm `helm history podinfo` shows a **new** revision whose description mentions a rollback — history isn't rewound, a rollback is itself a new entry. Confirm the release is back to its original defaults: 1 replica, no `logLevel` override.

<br>

<details><summary>Tip</summary>

```
helm history podinfo
helm rollback --help
```{{exec}}

Worth knowing: `--set` doesn't accumulate across upgrades. Setting `logLevel=debug` here alone, without `replicaCount=2` or `--reuse-values`, will silently drop the replica override from the last step back to the chart's default. It won't matter for this task — the rollback below clears everything anyway — but it will matter the next time you're not planning to roll back afterward.

</details>

<details><summary>Solution</summary>

```
helm upgrade podinfo podinfo/podinfo --version 6.5.4 --set logLevel=debug
```{{exec}}

```
helm history podinfo
```{{exec}}

```
helm rollback podinfo 1
```{{exec}}

```
helm history podinfo
helm get values podinfo
kubectl get pods -l app.kubernetes.io/name=podinfo
```{{exec}}

</details>
