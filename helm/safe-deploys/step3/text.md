
### Helm plugins

If you're serious about Helm, look at the [Helm plugins](https://helm.sh/docs/community/related/#helm-plugins) ecosystem — tools for developing, publishing and managing charts.

A few worth knowing:

```plain
helm plugin list
helm plugin -h
```{{exec}}

- **helm-diff** — shows what an upgrade *would* change, as a diff against the running release. The single most useful plugin for production work, and a good companion to `--dry-run=client`.
- **helm-secrets** — manages encrypted values files so secrets can live in Git.
- **helm-unittest** — unit tests for chart templates.

<br>

<details><summary>Info</summary>

Plugins install straight from a repository:

```plain
helm plugin install https://github.com/databus23/helm-diff
```

This step has no verification — it's here so you know the ecosystem exists.

</details>
