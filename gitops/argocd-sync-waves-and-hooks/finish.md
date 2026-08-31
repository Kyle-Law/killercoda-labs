
<br>

### Recap

- A sync wave is an integer annotation (`argocd.argoproj.io/sync-wave`, default `0`); Argo CD applies resources wave by wave, and a wave doesn't start until every resource in the previous one is Healthy — not just applied.
- Hooks (`argocd.argoproj.io/hook: PreSync|Sync|PostSync`) are one-shot Jobs tied to a phase of the sync, not a wave — but a hook can also carry a `sync-wave` annotation and gates progress exactly like any other resource would.
- Every hook runs on **every** sync, unconditionally — even a sync that only needs to fix one resource in a late wave still re-runs the PreSync hook and every earlier wave's Sync hooks from the top, whether or not that wave needed any changes at all.
- `hook-delete-policy` controls what happens to a hook's Job object after it runs, and the default (no policy, paired with `generateName`) is "never delete" — completed hook Jobs accumulate forever, one per sync. `BeforeHookCreation` replaces a fixed-name hook right before the next sync creates a new one, but leaves the last one sitting there in the meantime. `HookSucceeded` deletes it immediately once it succeeds — nothing lingers at all.
- `PostSync` specifically waits for Health, not Sync — it runs after the resources it follows are actually working, not merely applied.

### WELL DONE!

None of this changes what a sync fundamentally does — apply the desired state. Waves and hooks are entirely about *when*, layered on top of a mechanism that otherwise has no inherent ordering at all.
