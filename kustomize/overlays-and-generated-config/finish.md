
<br>

### Recap

- Kustomize is **text in, text out**. `kubectl kustomize` renders with no cluster and no state; `kubectl apply -k` renders and applies. There is no release object, nothing to roll back, and nothing to install — it's already in `kubectl`.
- An **overlay references a base**, it doesn't copy it. Each environment records only its differences, so a genuinely shared change — the image bump in step 2 — is one line in one file, and every environment inherits it.
- Matching in a kustomization happens against **base names**, before transformers run. `replicas: [{name: shop}]` matches `shop`, not `dev-shop`, even though `dev-shop` is what gets created.
- **`configMapGenerator` appends a hash of the content to the name**, and rewrites every reference to it — `configMapKeyRef`, `envFrom`, volume `configMap.name`. You never write the real name, so a name and its references cannot drift apart.
- That hash is what turns a config change into a **rolling update**: new content, new name, new pod template, new Pods. No `kubectl rollout restart`, no checksum annotation, no controller watching anything.
- **`disableNameSuffixHash: true` gives that up**, and the failure is silent — `apply` reports success, the Deployment is `unchanged`, and Pods serve the old values indefinitely. Whether a change ever reaches a running Pod then depends on how it's consumed: `env` never updates, a volume mount updates but the app may not re-read it, and `subPath` never updates.
- Generated ConfigMaps **accumulate**. Each new hash is a new object, and plain `apply -k` doesn't remove the old ones — that's what `kubectl apply --prune` or a GitOps engine's pruning is for.

### WELL DONE!

Two environments from one base, and a config change that redeploys itself — plus a first-hand look at the silent staleness bug you get the moment you turn that off.

Related labs in this set: `gitops/argocd-kustomize` for what Argo CD does when it runs `kustomize build` for you, and `probes/readiness-and-safe-rollouts` for making the rollout this lab triggers actually safe.
