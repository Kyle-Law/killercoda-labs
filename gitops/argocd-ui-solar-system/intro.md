
<br>

Every other lab in `gitops/` runs Argo CD **Core** — no UI, no API server, CLI only. This one runs the **full** install specifically to use the part Core skips: the web UI, reached over a NodePort on a real multi-node cluster, the way most people meet Argo CD for the first time.

The app is `siddharth67/solar-system` — a small, self-contained animated canvas app, no database, nothing else to install. Versions `v3` through `v9` exist on Docker Hub; this lab deploys `v3` and later bumps to `v9`.

Both Argo CD's own UI and the deployed app are reached through **NodePort** — Killercoda's traffic panel (top right of the terminal) gives you a clickable link for any port once it's exposed, or use the `ACCESS` links each step provides directly.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
