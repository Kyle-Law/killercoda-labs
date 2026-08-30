
`guestbook` is `Synced` and `Healthy` again, still on a manual sync policy — Argo CD does nothing here unless you tell it to.

Change something live, **bypassing Argo CD entirely** — scale the `guestbook-ui` Deployment in the `default` namespace to 3 replicas with `kubectl`, not `argocd`. Check `argocd app get guestbook`: what does it report now? Wait a bit and check again — does it fix itself?

Once you've confirmed it doesn't, put it back the way Git says it should be, using Argo CD rather than `kubectl`.

<br>

<details><summary>Tip</summary>

```
kubectl -n default scale deployment guestbook-ui --replicas=3
```{{exec}}

Give it 15–20 seconds before deciding it's not going to self-correct — but it won't. With no sync policy, Argo CD only ever *reports* drift; reacting to it is always a decision you make, not something that happens on its own.

</details>

<details><summary>Solution</summary>

```
kubectl -n default scale deployment guestbook-ui --replicas=3
```{{exec}}

```
argocd app get guestbook
```{{exec}}

`Sync Status: OutOfSync` — and notice `Health Status` still says `Healthy`. Three replicas is a perfectly healthy Deployment; it's just not the *one Git describes*. Sync and Health really are independent.

Wait, check again — still `OutOfSync`, indefinitely:

```
argocd app get guestbook
```{{exec}}

```
argocd app sync guestbook
```{{exec}}

```
kubectl -n default get deployment guestbook-ui
```{{exec}}

Back to 1 replica — reverted because you asked it to, not because Argo CD noticed on its own.

</details>
