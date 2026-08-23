
Deployment `web` has been through 3 releases. Find which revision ran `nginx:1.26-alpine`, then restore **exactly that revision** — not just "the previous one."

<br>

<details><summary>Tip</summary>

```
kubectl rollout history deployment/web
kubectl rollout history deployment/web --revision=2
```{{exec}}

`change-cause` in the history list is just a hint — confirm the actual image with `--revision=N` before you commit to a number.

</details>

<details><summary>Solution</summary>

```
kubectl rollout history deployment/web --revision=1
kubectl rollout history deployment/web --revision=2
kubectl rollout history deployment/web --revision=3
```{{exec}}

Revision 2 shows `nginx:1.26-alpine`.

```
kubectl rollout undo deployment/web --to-revision=2
kubectl rollout status deployment/web
```{{exec}}

</details>
