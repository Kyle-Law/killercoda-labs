
<br>

### Recap

- `--dry-run=client` renders and validates without touching the cluster; add `--debug` for the full picture.
- `--wait` blocks until resources are actually ready. In Helm 4 it takes a *strategy* (`watcher`, `hookOnly`, `legacy`), and defaults to `hookOnly` when the flag is omitted entirely.
- `--rollback-on-failure` replaces Helm 3's `--atomic`: on failure the release reverts instead of leaving a half-applied mess. `--atomic` still works but warns that it's deprecated.
- `--cleanup-on-fail` deletes resources newly created by a failed upgrade, which `--rollback-on-failure` alone doesn't do.

Next: `packaging/helm-failed-upgrades` isolates each failure mode one at a time — including the naive case with no `--wait` at all, where `STATUS: deployed` doesn't mean the Pod ever came up — and covers reviving a release after `helm uninstall`.

### Happy Helming!
