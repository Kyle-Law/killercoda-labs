
<br>

### Recap

| Symptom | Cause | Fix |
|---|---|---|
| Forbidden, no binding | Role exists, nothing binds it | create a RoleBinding |
| Forbidden, binding exists | Role's `rules` don't grant the verb needed | edit/reapply the Role |
| Forbidden, ClusterRole + binding exist | RoleBinding scoped to a namespace can't authorize a cluster-scoped resource | use a ClusterRoleBinding instead |

### WELL DONE!

`kubectl auth can-i ... --as=<identity>` is the one command that answers all three — it tells you the actual outcome of the RBAC evaluation without needing to trace Role → Binding → Subject by hand.
