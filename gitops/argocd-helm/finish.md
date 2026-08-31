
<br>

### Recap

- Argo CD renders a Helm chart with `helm template` and applies the resulting manifests directly. No `helm install` ever runs, so no release Secret exists — `helm list` and `helm status` show nothing, even for an Application that's genuinely, correctly Helm-templated. A chart's own `app.kubernetes.io/managed-by: Helm` label survives into the output regardless — it describes the chart's authorship, not proof that a release exists.
- `--helm-set` / `--helm-set-string` / `--helm-set-file` are the exact same flags, with the exact same type-coercion behavior, as plain `helm upgrade --set` / `--set-string` / `--set-file` from `packaging/helm-values-precedence`.
- `--values-literal-file` reads a **local** file and embeds its content directly into the Application's own spec as `helm.valuesObject` — no Git commit required. The difference from a plain `helm -f` flag isn't where it reads from, it's where it ends up: this becomes part of the Application's persisted desired state, not a value you have to remember to re-pass on every future change.
- `--values <path>`, by contrast, needs that path to exist **inside the source** — a file actually committed alongside the chart in Git. Point it at a bare chart-repository source (no Git repo, just the packaged chart) and Argo CD rejects it immediately, before ever touching the cluster, because there's no such file to find.

### WELL DONE!

Same chart, same values, same `helm template` under the hood — everything downstream of that is genuinely different from a plain `helm install`.
