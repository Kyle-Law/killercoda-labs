
`rollouts-demo` is healthy on `blue` again. Update to `argoproj/rollouts-demo:red` — imagine you've spotted something wrong the moment it starts rolling out, before it ever reaches its first pause. Abort it, and check the result three ways: what's actually running, what the `Rollout`'s own **spec** says should be running, and what its status phase is. Is this the same as if the update had simply never been requested?

<br>

<details><summary>Tip</summary>

```
kubectl argo rollouts abort --help
```{{exec}}

Check `Status:` after aborting, not just the image — `Degraded` and `Healthy` are not the same claim. Then check `spec.template.spec.containers[0].image` directly with `kubectl get rollout -o jsonpath=...`, separately from what `kubectl argo rollouts get rollout` shows you for "Images:". One of those two answers is not like the other.

</details>

<details><summary>Solution</summary>

```
kubectl argo rollouts set image rollouts-demo rollouts-demo=argoproj/rollouts-demo:red
kubectl argo rollouts abort rollouts-demo
```{{exec}}

```
kubectl argo rollouts get rollout rollouts-demo --watch=false
```{{exec}}

`Images:` shows only `blue` — `red` never got real traffic and the revert was immediate. But `Status: Degraded`, with a message naming the aborted revision — not `Healthy`. An abort is a recorded, visible event: something was intentionally stopped mid-flight, kept distinct from "this rollout has always been fine."

```
kubectl get rollout rollouts-demo -o jsonpath='{.spec.template.spec.containers[0].image}'
```{{exec}}

`red` — the Rollout's own spec never changed back. Abort didn't undo your request, it just refused to act on it any further, leaving the actual running Pods on `blue` and the spec permanently disagreeing with them until you fix it yourself. Familiar shape: `gitops/argocd-history-and-rollback` found the exact same thing about `argocd app rollback` not updating an Application's `spec.source` — a "rollback"-flavored operation changing what's live without changing what's asked for is a pattern, not a coincidence, across this whole project family.

```
kubectl argo rollouts get rollout rollouts-demo --watch=false | grep -i revision
```{{exec}}

The aborted revision is still numbered and still in the history — same append-only principle as everything else with "revision" in its name in this whole `gitops/` set.

</details>
