
Two experiments, same drift, different policy each time.

**First:** turn on `automated` sync — but not self-heal. Scale `guestbook-ui` to 3 replicas with `kubectl` again, exactly like last step. Watch for 15–20 seconds: does `automated` alone catch it?

**Second:** now add self-heal on top of automated. Repeat the exact same drift. This time watch closely — how long does it take?

Leave `guestbook` on automated + self-heal, healthy, back at 1 replica, when you're done.

<br>

<details><summary>Tip</summary>

```
argocd app set --help | grep -B1 -A2 'sync-policy\|self-heal'
```{{exec}}

`--self-heal` on its own, with no automated sync policy set, does nothing — self-heal is a modifier on automated sync, not a policy by itself.

</details>

<details><summary>Solution</summary>

```
argocd app set guestbook --sync-policy automated
kubectl -n default scale deployment guestbook-ui --replicas=3
```{{exec}}

```
argocd app get guestbook
```{{exec}}

Wait, check again — still `OutOfSync`:

```
argocd app get guestbook
```{{exec}}

`automated` alone only reacts to **new commits in Git** — it polls the repo, not the live cluster. A `kubectl` change underneath it is invisible to that mechanism entirely.

```
argocd app set guestbook --sync-policy automated --self-heal
kubectl -n default scale deployment guestbook-ui --replicas=3
```{{exec}}

```
argocd app get guestbook
kubectl -n default get deployment guestbook-ui
```{{exec}}

This time it's back to 1 replica within a couple of seconds, with no `argocd app sync` from you at all. `selfHeal` is what makes Argo CD watch the live cluster too, not just Git.

</details>
