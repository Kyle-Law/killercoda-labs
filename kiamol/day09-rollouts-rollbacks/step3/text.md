
Pause `api`'s rollout. While it's paused, make **two** changes to its Pod template: update the image to `nginx:1.26-alpine`, and add an environment variable `RELEASE_NOTES=batched-update` to the container. Resume the rollout.

Confirm both changes landed in a **single** new revision — not two. Skip the pause, and you'll get two revisions instead of one.

<br>

<details><summary>Tip</summary>

```
kubectl rollout pause --help
```{{exec}}

While paused, `kubectl set image` and `kubectl set env` both edit the Deployment's spec normally — they just don't trigger a rollout until you resume.

</details>

<details><summary>Solution</summary>

```
kubectl rollout pause deployment/api
```{{exec}}

```
kubectl set image deployment/api nginx=nginx:1.26-alpine
kubectl set env deployment/api RELEASE_NOTES=batched-update
```{{exec}}

```
kubectl rollout resume deployment/api
kubectl rollout status deployment/api
```{{exec}}

```
kubectl rollout history deployment/api
```{{exec}}

Exactly one new revision, carrying both changes.

</details>
