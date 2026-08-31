
`rollouts-bluegreen` is healthy on `blue` — 3 replicas, two Services in front of it: `rollouts-bluegreen-active` (real traffic) and `rollouts-bluegreen-preview` (nothing points at it yet, but it's live).

Update the image to `argoproj/rollouts-demo:yellow`. Before promoting anything, check the total Pod count and which Pods each Service actually routes to. Then `promote`, and check both again.

<br>

<details><summary>Tip</summary>

```
kubectl argo rollouts set image rollouts-bluegreen rollouts-demo=argoproj/rollouts-demo:yellow
kubectl get pods -l app=rollouts-bluegreen
```{{exec}}

Canary shrinks the old version's replica count as the new one grows, so the total stays at `spec.replicas`. Blue-green doesn't shrink anything until you promote — check whether that changes what the total Pod count looks like here.

</details>

<details><summary>Solution</summary>

```
kubectl argo rollouts set image rollouts-bluegreen rollouts-demo=argoproj/rollouts-demo:yellow
```{{exec}}

```
kubectl get pods -l app=rollouts-bluegreen
kubectl get endpoints rollouts-bluegreen-active -o jsonpath='{.subsets[0].addresses[*].targetRef.name}'
kubectl get endpoints rollouts-bluegreen-preview -o jsonpath='{.subsets[0].addresses[*].targetRef.name}'
```{{exec}}

6 Pods, not 3 — both versions running at *full* replica count simultaneously. `active` still routes only to `blue` Pods; `preview` routes only to `yellow`. Nothing about real traffic changed yet — `yellow` is fully up and fully testable through the preview Service, completely invisible to whoever's hitting `active`.

```
kubectl argo rollouts promote rollouts-bluegreen
```{{exec}}

```
kubectl get endpoints rollouts-bluegreen-active -o jsonpath='{.subsets[0].addresses[*].targetRef.name}'
kubectl argo rollouts get rollout rollouts-bluegreen --watch=false
```{{exec}}

`active` now routes to the `yellow` Pods — instantly, not gradually the way canary's `setWeight` steps did it. That's the entire trade blue-green makes: pay for double the capacity for a while, get a cutover with zero gradual-exposure window at all.

</details>
