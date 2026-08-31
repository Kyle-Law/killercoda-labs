
`rollouts-demo` is healthy on `blue`, at 100%, 5 replicas. Update the image to `argoproj/rollouts-demo:yellow` and immediately check status — it should be paused already. Confirm the replica split matches the first step's `setWeight: 20` (exactly 1 of 5 on the new version), and confirm it's still paused a good 20 seconds later, with nobody having touched it.

Then `promote` it once. It should sail past `setWeight: 60`'s pause on its own after 10 seconds — figure out why *that* one doesn't need a second `promote` the way the first one did, given they're both just `pause` steps in the same list.

<br>

<details><summary>Tip</summary>

```
kubectl argo rollouts set image rollouts-demo rollouts-demo=argoproj/rollouts-demo:yellow
kubectl argo rollouts get rollout rollouts-demo --watch=false
```{{exec}}

Compare the two `pause` steps in the spec: `pause: {}` versus `pause: {duration: 10}`. One of them has an exit condition built in; the other doesn't.

</details>

<details><summary>Solution</summary>

```
kubectl argo rollouts set image rollouts-demo rollouts-demo=argoproj/rollouts-demo:yellow
kubectl argo rollouts get rollout rollouts-demo --watch=false
```{{exec}}

`Status: Paused`, `SetWeight: 20`, one Pod on `yellow` (`canary`), four still on `blue` (`stable`) — the weight is a real replica split, not a label on a proxy rule.

```
sleep 20
kubectl argo rollouts get rollout rollouts-demo --watch=false
```{{exec}}

Still paused, unchanged — `pause: {}` has no timer, so nothing but an explicit `promote` moves it forward.

```
kubectl argo rollouts promote rollouts-demo
```{{exec}}

```
sleep 15
kubectl argo rollouts get rollout rollouts-demo --watch=false
```{{exec}}

`Status: Healthy`, 100% `yellow`. It passed through `setWeight: 60` and its `pause: {duration: 10}` without a second `promote` — that pause carries its own 10-second timer, so it resumes on its own once that elapses. Same step type, opposite default: no duration means wait forever, a duration means wait exactly that long.

</details>
