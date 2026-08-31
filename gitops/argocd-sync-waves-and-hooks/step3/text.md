
A different Application, `pre-post-sync`: a real guestbook Deployment, wrapped with a `PreSync` hook (`before`, sleeps 10s) and a `PostSync` hook (`after`, sleeps 10s) — both using `hook-delete-policy: HookSucceeded`, unlike anything in `sync-waves`.

Sync it, and this time watch **while it's still running**: does the `after` Job start the instant the Deployment's Pods exist, or does it wait for the Deployment to actually be Health-checked as `Healthy` first? Once everything's done, check whether `before` and `after` are still sitting around — compare that against `sync-waves` last step.

<br>

<details><summary>Tip</summary>

```
argocd app sync pre-post-sync --async
watch kubectl -n default get deploy,job
```{{exec}}

`--async` returns immediately instead of blocking your terminal until the whole sync finishes, so you can watch it unfold. `PostSync` is specifically gated on **Health**, not Sync — a Deployment can be `Synced` (manifest applied) well before it's `Healthy` (Pods actually Ready).

</details>

<details><summary>Solution</summary>

```
argocd app sync pre-post-sync --async
```{{exec}}

```
watch -n1 kubectl -n default get deploy,job
```{{exec}}

Ctrl+C once `after` shows `Running`. The Deployment reaches Ready well before `after` starts — it's waiting on Health, not just on the Deployment existing.

```
kubectl -n default get job
```{{exec}}

No `before`, no `after` — both are already gone, deleted the moment they succeeded. `sync-waves`' hooks are still sitting there from last step; these never even had the chance to linger.

</details>
