
Scaffold a brand-new local chart named `webapp` with `helm create` — no repo involved at all. Look inside: `Chart.yaml`, `values.yaml`, `templates/`. It's just files.

The scaffold's default image tag resolves to an old nginx version (`Chart.yaml`'s `appVersion`, used as the image tag whenever `values.yaml`'s `image.tag` is left empty). Install it as a release named `webapp` **straight from the local directory**, overriding `image.tag` to `stable-alpine`. Confirm it's running on the overridden tag, not the ancient default.

<br>

<details><summary>Tip</summary>

```
helm create webapp
cat webapp/Chart.yaml
cat webapp/values.yaml
```{{exec}}

`helm install <release-name> <path>` works on a local directory exactly like it works on a repo chart — a repo is just a place charts are published, not a requirement for installing one.

</details>

<details><summary>Solution</summary>

```
helm create webapp
```{{exec}}

```
helm install webapp ./webapp --set image.tag=stable-alpine
```{{exec}}

```
helm list
kubectl get pods -l app.kubernetes.io/name=webapp -o jsonpath='{.items[0].spec.containers[0].image}'
```{{exec}}

</details>
