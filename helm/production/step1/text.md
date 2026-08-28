
### Helm install flags

Imagine you have to deploy to production and the CI/CD pipeline isn't working, so you're doing it by hand.

The prudent first step is a dry run. This renders the chart (proving the YAML is syntactically valid) and sends it to the API server for validation — catching missing CRDs, admission webhook rejections, and similar — without creating anything:

```plain
helm install webserver podinfo/podinfo --dry-run=client --debug
```{{exec}}

> In Helm 4 a bare `--dry-run` is deprecated; be explicit with `--dry-run=client` (render and validate locally) or `--dry-run=server` (also run server-side dry-run through admission control).

<br>

Next, `--wait` makes Helm block until the resources are genuinely ready rather than merely created, and `--timeout` bounds that wait. On failure you'd normally be left with a partially installed release — `--rollback-on-failure` cleans that up for you.

Try an install that is *designed* to fail, by giving it an image tag that doesn't exist and far too little time:

```plain
helm install webserver podinfo/podinfo \
  --set image.tag=does-not-exist \
  --wait --timeout 20s --rollback-on-failure --debug
```{{exec}}

It fails — as intended. Now confirm that it cleaned up after itself, leaving no release and no stray resources:

```plain
helm ls -a
kubectl get pods
```{{exec}}

<br>

<details><summary>Info: what changed in Helm 4</summary>

`--atomic` was the Helm 3 spelling of this behaviour. It still works, but prints:

```plain
Flag --atomic has been deprecated, use --rollback-on-failure instead
```

`--wait` also changed: it now takes a strategy (`--wait=watcher`, `--wait=hookOnly`, `--wait=legacy`). Using `--wait` on its own selects `watcher`; omitting the flag entirely defaults to `hookOnly`.

</details>
