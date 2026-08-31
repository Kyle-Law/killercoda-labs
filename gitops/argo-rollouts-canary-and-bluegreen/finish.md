
<br>

### Recap

- A `Rollout`'s very first deployment has no previous stable version to canary against — it goes straight to 100%, steps and all. Canary steps only apply to an *update* against an existing stable revision.
- Each canary step's `setWeight` is enforced through real replica counts on two coexisting ReplicaSets, not a proxy-layer traffic split — 20% of 5 replicas is genuinely 1 Pod on the new version, 4 on the old.
- `pause: {}` (no duration) holds indefinitely until something explicitly calls `promote`. `pause: {duration: N}` holds for exactly `N` and then continues on its own — same step type, opposite default behavior.
- `abort` doesn't quietly put things back — it reverts to the last stable version *and* marks the Rollout `Degraded`, an explicit, visible signal that an update was intentionally stopped rather than a rollout that simply never happened.
- Blue-green doesn't shift traffic gradually at all — it runs the new version at full replica count *alongside* the old one, invisible to real traffic via a separate preview Service, and `promote` cuts the active Service over all at once. Canary trades capacity for gradual exposure; blue-green trades double capacity for an instant, fully-tested cutover.

### WELL DONE!

Same underlying idea as everything else in `gitops/` — a controller continuously reconciling desired state against live state — aimed at a much narrower question: not *whether* the new version should be running, but *how much of it should be visible, right now*.
