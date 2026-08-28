
<br>

### Recap

- By default, `helm upgrade` (and `install`) only waits for the API server to accept the manifests — it does not check that Pods actually come up. A release can sit at `STATUS: deployed` while every Pod behind it is crash-looping or stuck on a bad image.
- `--wait` (with `--timeout`) makes Helm poll workload readiness before returning. If the timeout passes without success, the command fails **and** the release status is honestly recorded as `failed`.
- `--rollback-on-failure` implies `--wait`, and goes further: on failure Helm automatically rolls the release back to the last successful revision. That rollback is a **new** revision, exactly like a manual `helm rollback` — `helm history` still only grows. (`--atomic` is the deprecated Helm 3 name for the same flag — it still works, with a warning.)
- `helm uninstall` normally deletes the release's history along with its resources. `--keep-history` leaves the record behind with status `uninstalled` — still visible in plain `helm list` (which shows every status by default), narrow it with `--uninstalled` or filter it back out with `--deployed`. Because the history survives, `helm rollback` can revive it — no `helm install` required.

### WELL DONE!

The pattern across all three recovery flags is the same one from `kubectl rollout status --timeout` and `kubectl rollout undo`: Helm's release status is only ever as honest as the checks you ask it to run, and "roll back" always means "create something new that looks like something old" — never rewinding time.

None of the broken upgrades here needed more than one `--set`. For what happens once real installs layer `-f` files and `--set` on top of each other, see `packaging/helm-values-precedence`.

This lab didn't touch `--dry-run` or `--cleanup-on-fail` — see `helm/safe-deploys` for those, plus a look at the wider Helm plugin ecosystem.
