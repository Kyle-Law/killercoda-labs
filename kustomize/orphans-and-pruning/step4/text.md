
`--prune` deletes everything matching the selector that wasn't in this apply. That sentence contains the danger: **the selector defines what gets deleted, not the kustomization.**

Anything wearing that label — regardless of who created it, or why — is now in scope.

**1.** Create a ConfigMap in `demo` that has nothing to do with this kustomization, but happens to carry the same label.
**2.** Re-run the same prune command.
**3.** Save what survived to `/root/survivors.txt`.

<br>

<details><summary>Solution</summary>

Something another team owns, labelled the same way:

```plain
kubectl create configmap other-team-config -n demo --from-literal=owner=platform
kubectl label configmap other-team-config -n demo managed-by=app-kustomize
kubectl get configmap -n demo --show-labels
```{{exec}}

Run exactly the same command as before — nothing about it has changed:

```plain
kubectl apply -k /root/app --prune -l managed-by=app-kustomize
```{{exec}}

```plain
kubectl get configmap -n demo -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
  | grep -v '^kube-root-ca.crt$' | sort | tee /root/survivors.txt
```{{exec}}

</details>

<br>

## Gone

`other-team-config` was created seconds ago, by a different process, for a different purpose. It was never in your kustomization. `--prune` deleted it anyway, because it matched the selector and wasn't in the apply — which is precisely what you asked for.

That is the trade `--prune` makes. It solves orphan detection by declaring a region of the cluster to be **exclusively yours**, and then enforcing that claim. If the claim is wrong, the enforcement is destructive and immediate.

Three things follow:

- **Make the selector specific to one kustomization**, not to a team or an app. A label like `managed-by: app-kustomize` is far too broad if two kustomizations could ever both use it.
- **Scope by namespace as well**, so a mistake can't reach beyond it.
- **Dry-run first.** `kubectl diff -k` won't show prunes, so the safe check is to list what the selector currently matches and confirm you recognise all of it:

```plain
kubectl get all,configmap,secret -n demo -l managed-by=app-kustomize
```{{exec}}

This is also why GitOps controllers treat pruning as a first-class, opt-in setting with its own ownership metadata rather than a label you chose — Argo CD tracks resources by application, not by whatever selector you passed on the command line.
