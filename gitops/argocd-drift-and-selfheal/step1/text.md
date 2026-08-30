
Argo CD Core is installed — no API server running, so the CLI talks to the cluster directly through your kubeconfig. Log in to core mode, then look at the `guestbook` Application: it exists, but nothing has been synced yet.

Sync it, then immediately run `argocd app get guestbook` again. Look closely at **Sync Status** and **Health Status** — they might not agree. What does each one actually mean, and why can a resource be `Synced` but not yet `Healthy`?

<br>

<details><summary>Tip</summary>

```
argocd login --core
```{{exec}}

Sync Status answers "does live state match what's in Git?" Health Status answers "is that live state actually working?" A freshly-created Deployment can be `Synced` (the manifest was applied) while still `Progressing` (the Pod hasn't come up yet) — two different questions, checked two different ways.

</details>

<details><summary>Solution</summary>

```
argocd login --core
```{{exec}}

```
argocd app get guestbook
```{{exec}}

`Sync Status: OutOfSync`, `Health Status: Missing` — nothing's been created yet.

```
argocd app sync guestbook
```{{exec}}

```
argocd app get guestbook
```{{exec}}

Right after the sync, don't be surprised to see `Synced` paired with `Progressing` rather than `Healthy` — give it a few seconds and check again. Once the Pod is Ready, both settle to `Synced` / `Healthy`.

</details>
