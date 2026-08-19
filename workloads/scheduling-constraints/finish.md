
<br>

### Recap

| Constraint | Effect | Fix |
|---|---|---|
| `nodeSelector` | Pod requires a label no node has | label the node, or adjust the Pod |
| Taint, no toleration | Node actively refuses Pods that don't tolerate it | add a matching `toleration` (get → edit → delete → reapply) |
| `podAntiAffinity` (required) | Hard constraint the topology can't satisfy | relax to `preferred`, or add more nodes |

### WELL DONE!

`required` constraints fail closed — the scheduler won't compromise. `preferred` constraints are best-effort. Knowing which one you actually need, and reading `kubectl describe pod`'s Events to tell them apart, is most of this skill.
