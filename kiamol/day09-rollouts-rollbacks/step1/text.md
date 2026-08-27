
Deployment `web` has been through 3 releases. The current one is broken — its change-cause records it as `bad release - checkout errors`.

Roll back to the release recorded in the history as **`last known good`**. You'll need to consult the rollout history to work out which revision that is, and restore *exactly* that revision — not just "the previous one."

<br>

<details><summary>Tip</summary>

```
kubectl rollout history deployment/web
```{{exec}}

That lists each revision with its change-cause. To see what a particular revision actually deployed:

```
kubectl rollout history deployment/web --revision=2
```{{exec}}

</details>

<details><summary>Solution</summary>

```
kubectl rollout history deployment/web
```{{exec}}

Revision 2 is the one annotated `last known good`. Confirm what it deployed before committing to it:

```
kubectl rollout history deployment/web --revision=2
```{{exec}}

```
kubectl rollout undo deployment/web --to-revision=2
kubectl rollout status deployment/web
```{{exec}}

```
kubectl get deployment web -o jsonpath='{.spec.template.spec.containers[0].image}'
```{{exec}}

</details>
