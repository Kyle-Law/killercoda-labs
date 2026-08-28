
<br>

`kiamol/day10-helm` covers the happy path: install, override values, roll back, package a chart. This lab covers what happens when an upgrade goes wrong — which is most of what actually matters under exam pressure, because `helm list` saying `deployed` is not the same claim as "the app is running".

Four independent releases, one lesson each:

- `podinfo` — an upgrade can report `deployed` while the Pod is broken, because by default Helm only checks that the API server accepted the manifest.
- `podinfo2` — `--wait` makes Helm actually check, and tells you the truth (`failed`) if the workload never comes up.
- `podinfo3` — `--atomic` goes one step further: on failure, Helm rolls the release back for you, automatically.
- `podinfo4` — `helm uninstall --keep-history` doesn't have to be permanent. A release with kept history can be rolled back from the grave.

`helm` isn't installed by default here, so the first step's background installs it — same as `day10-helm`, not the skill being tested.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
