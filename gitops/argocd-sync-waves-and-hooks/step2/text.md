
`sync-waves` just finished its first sync. Note the two hook Jobs' names: `upgrade-sql-schema...` has a random suffix (`generateName`), `maint-page-up`/`maint-page-down` have fixed names.

Trigger another sync — nothing in Git changed, so this should be a no-op in terms of *content*. But does it re-run the hooks anyway? And do the **old** hook Job objects from the first sync still exist afterward, or did they get replaced?

Check both hook Jobs' `UID` before and after, and count how many `upgrade-sql-schema...` Jobs exist once you're done.

<br>

<details><summary>Tip</summary>

```
kubectl -n default get job -o custom-columns='NAME:.metadata.name,UID:.metadata.uid'
```{{exec}}

A sync always re-runs every hook — it isn't conditional on anything in that wave having actually changed. What differs is what happens to the *previous* hook Job object once the new one exists, and that depends entirely on `hook-delete-policy` — read each Job's annotations to see which policy (if any) it's using.

</details>

<details><summary>Solution</summary>

```
kubectl -n default get job -o custom-columns='NAME:.metadata.name,UID:.metadata.uid'
```{{exec}}

```
argocd app sync sync-waves
```{{exec}}

```
kubectl -n default get job -o custom-columns='NAME:.metadata.name,UID:.metadata.uid'
```{{exec}}

`maint-page-up` and `maint-page-down` have **new** UIDs — same name, different object, because `hook-delete-policy: BeforeHookCreation` deleted the old one right before this sync created a new one. The `upgrade-sql-schema...` Job from the first sync is still sitting there completed, **and** there's now a second one alongside it — no `hook-delete-policy` was set on it at all, and its `generateName` means nothing stops a new one from existing alongside the old. Sync this a few more times and that count only ever goes up.

</details>
