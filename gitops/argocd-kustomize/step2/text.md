
`kustomize-guestbook` is back to a clean default sync — image `gcr.io/google-samples/gb-frontend:v5`, 1 replica, nothing overridden.

Swap the image entirely, to `nginx:1.27-alpine`, and bump replicas to `3` — without editing `kustomization.yaml` or adding a patch file. Confirm both took effect on the live Deployment. (`gb-frontend` genuinely only has one tag published, `v5` — worth confirming yourself against the registry before assuming an old sample image has more than it does.)

<br>

<details><summary>Tip</summary>

```
argocd app set --help | grep -A2 'kustomize-image\|kustomize-replica'
```{{exec}}

`--kustomize-image` takes `oldImage=newImage[:tag]` — it isn't limited to bumping a tag on the same image, it can replace the image outright. `--kustomize-replica` takes the resource's **final** (post-prefix) name — `kustomize-guestbook-ui`, not `guestbook-ui`.

</details>

<details><summary>Solution</summary>

```
argocd app set kustomize-guestbook --kustomize-image gcr.io/google-samples/gb-frontend=nginx:1.27-alpine
argocd app sync kustomize-guestbook
```{{exec}}

```
kubectl -n default get deployment kustomize-guestbook-ui -o jsonpath='{.spec.template.spec.containers[0].image}'
```{{exec}}

```
argocd app set kustomize-guestbook --kustomize-replica kustomize-guestbook-ui=3
argocd app sync kustomize-guestbook
```{{exec}}

```
kubectl -n default get deployment kustomize-guestbook-ui -o jsonpath='{.spec.replicas}'
```{{exec}}

Both changes live entirely in the Application's own spec — the same relationship `--helm-set` has to a Helm source, for a Kustomize one instead.

</details>
