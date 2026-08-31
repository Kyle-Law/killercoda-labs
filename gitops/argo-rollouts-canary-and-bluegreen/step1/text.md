
`rollouts-demo` just deployed for the first time — a canary `Rollout`, replicas: 5, steps set to 20% → pause → 60% → pause 10s. Check its status.

Given those steps, you might expect to see it sitting paused at 20% right now, waiting for you. It isn't. Work out why the very first deployment of a `Rollout` never touches its canary steps at all.

<br>

<details><summary>Tip</summary>

```
kubectl argo rollouts get rollout rollouts-demo --watch=false
```{{exec}}

Canary steps describe how to move *from* a stable version *to* a new one. On the very first deploy, there is no stable version yet — there's nothing to be careful about being wrong about.

</details>

<details><summary>Solution</summary>

```
kubectl argo rollouts get rollout rollouts-demo --watch=false
```{{exec}}

`Status: Healthy`, `Step: 4/4`, `SetWeight: 100` — it went straight to 100% and skipped every step. There's no "old" version running anywhere for a canary rollout to gradually replace; canary steps only matter starting with the *second* deploy, once there's a stable revision on record to compare against.

</details>
