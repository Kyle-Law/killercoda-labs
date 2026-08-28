
### Helm upgrade flags

Install a working release first, so there's something to upgrade:

```plain
helm install webserver podinfo/podinfo --wait
```{{exec}}

Now attempt an upgrade that will fail, protected by both relevant flags:

```plain
helm upgrade webserver podinfo/podinfo \
  --set image.tag=does-not-exist \
  --wait --timeout 20s --rollback-on-failure --cleanup-on-fail --debug
```{{exec}}

Confirm the release survived and is back on a working revision:

```plain
helm history webserver
kubectl get pods
```{{exec}}

<br>

<details><summary>Info: why both flags</summary>

`--rollback-on-failure` reverts the release to the previous successful revision.

`--cleanup-on-fail` deletes resources that the failed upgrade newly **created**. Without it, resources that didn't exist before the upgrade can be left dangling in the cluster even after the rollback, because they aren't part of the revision being restored.

</details>
