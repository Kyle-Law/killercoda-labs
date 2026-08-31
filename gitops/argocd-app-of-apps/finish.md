
<br>

### Recap

- App-of-Apps is nothing exotic — a parent Application whose rendered output happens to be `Application` manifests instead of Deployments and Services. Each child is a fully independent Application afterward: its own sync status, its own health, its own sync policy.
- A child template's `resources-finalizer.argocd.argoproj.io` finalizer is what makes removing an entry from the parent actually clean up — without it, pruning the child `Application` object would leave its own Deployment, Service, and everything else it created still running, orphaned with nothing left tracking them.
- `ApplicationSet`'s **list** generator is a static, hand-maintained enumeration — you add or remove elements yourself, the same as adding or removing an entry from an App-of-Apps parent's values.
- Its **git directory** generator is not static — it continuously reconciles the live set of Applications against whatever currently matches its path pattern in the repo. Narrow the pattern, and an Application that no longer matches gets pruned automatically, with no list to edit and no sync to trigger by hand.

### WELL DONE!

Both patterns solve "I have more than one of these to manage" — the dividing line is whether the *set* itself is something you decide, or something the repository's structure already decides for you.
