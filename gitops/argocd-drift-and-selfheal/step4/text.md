
`guestbook` is healthy, still on automated sync + self-heal from last step.

Field-level drift (a replica count) is one kind of "live state disagrees with Git." Deleting a resource outright is another. Delete the `guestbook-ui` Service entirely with `kubectl` — not the Deployment, just the Service — and watch what happens.

<br>

<details><summary>Tip</summary>

```
kubectl -n default get svc guestbook-ui
```{{exec}}

Self-heal isn't specifically "watch for field changes" — it's "keep live state matching Git," and a missing resource is just as much a mismatch as a wrong field value.

</details>

<details><summary>Solution</summary>

```
kubectl -n default delete svc guestbook-ui
```{{exec}}

```
kubectl -n default get svc guestbook-ui
```{{exec}}

Give it a couple of seconds if it's not there yet, then check again — it comes back on its own, no `argocd app sync` involved:

```
kubectl -n default get svc guestbook-ui
argocd app get guestbook
```{{exec}}

</details>
