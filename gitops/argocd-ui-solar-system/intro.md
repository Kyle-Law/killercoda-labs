
<br>

Every other lab in `gitops/` runs Argo CD **Core** — no UI, no API server, CLI only. This one runs the **full** install specifically to use the part Core skips: the web UI, reached over a NodePort on a real multi-node cluster, the way most people meet Argo CD for the first time.

The app is `handafew/solar-system` — a small, self-contained animated solar-system page served by nginx, no database, nothing else to install. Versions `v1` through `v9` exist on Docker Hub, each highlighting a different planet; this lab deploys `v3` (Earth) and later bumps to `v9` (Pluto).

Both Argo CD's own UI and the deployed app are reached through **NodePort** — Killercoda's traffic panel (top right of the terminal) gives you a clickable link for any port once it's exposed, or use the `ACCESS` links each step provides directly.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
