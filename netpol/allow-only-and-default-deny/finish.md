
<br>

### Recap

- A `NetworkPolicy` only ever **allows**. Blocking happens as a side effect of *selecting*: a Pod no policy selects accepts everything, and a Pod any policy selects is denied by default for the directions in its `policyTypes`, then allowed back what the rules list.
- `podSelector` chooses the Pods being **protected**, not the ones being permitted. To let a new client reach `api`, you edit the policy that selects `api` — a policy selecting the client would govern traffic to *it* instead.
- Tightening one Pod does nothing for its neighbours. In step 1 a policy on `api` left `db` accepting connections from anywhere, because coverage is per-Pod and silence means open.
- **`policyTypes` names directions that become denied by default.** Adding `Egress` without writing any `egress:` rules kills every outbound connection the Pod makes — and shows up first as DNS failures, because name resolution is itself outbound. Never name a direction you aren't writing rules for.
- Omitting `policyTypes` makes Kubernetes infer it from the rule blocks present, so a policy with only `ingress:` rules governs ingress alone.
- Policies **combine as a union of allows**. There is no ordering, no priority and no override. A namespace-wide `podSelector: {}` deny-all plus one small policy per permitted path gives you a set where each policy is readable alone and nothing added later can silently undo an earlier allow.
- A namespace-level deny-all covers Pods that don't exist yet — `metrics` was protected the moment it started, with no new policy written.
- Enforcement is the **CNI's** job. On a cluster whose plugin ignores NetworkPolicy, everything here applies cleanly and protects nothing.

### WELL DONE!

Fifteen possible directions between four components, three of them open, and every policy in the set independently readable.

> Under `from`, two `podSelector` entries as separate list items mean **OR**; selectors combined inside a single list item mean **AND**. That distinction, and reaching across namespaces with `namespaceSelector`, is where policies most often end up quietly more permissive than intended — a natural next lab.
