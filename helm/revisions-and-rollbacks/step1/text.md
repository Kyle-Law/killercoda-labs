
The `webserver` release in the `default` namespace has been upgraded twice. Its Pods are now failing.

List the revision history of the release and write it into `/root/history`.

<br>

<details><summary>Tip</summary>

```plain
helm ls
helm history -h
```{{exec}}

Compare it with what the cluster shows:

```plain
kubectl get pods
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
helm history webserver
```{{exec}}

```plain
helm history webserver > /root/history
```{{exec}}

Three revisions, all `deployed`/`superseded` — Helm considers the last upgrade a success, because it only applied the manifests. It never checked that the Pods actually started.

</details>
