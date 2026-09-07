
<br>

Overlays are how Kustomize handles environments, and they work well until features start crossing them.

You add monitoring. Staging and prod both need it, so the patch is copied into both. Then HA, which prod needs and staging doesn't. Then a debug sidecar for staging only. Before long the number of overlay directories is the number of environments **multiplied by** the number of optional features, and most of them are near-identical copies.

The failure mode isn't the disk space — it's that a change to a shared feature is now a find-and-replace across directories, and the one you miss becomes environment drift nobody notices until it matters.

**Components** are the fix: a feature defined once, and pulled in by whichever overlays want it.

> `/root/app` has a base and two overlays, `staging` and `prod` — each carrying its own copy of the same monitoring patch.
