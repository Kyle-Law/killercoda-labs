
Detecting orphans by subtraction doesn't scale. The alternative is to make ownership explicit: stamp every object the kustomization produces with a label, then tell `apply` to delete anything carrying that label which it did not just apply.

**1.** Add a `labels:` entry to the kustomization stamping `managed-by: app-kustomize` on everything.
**2.** Apply with `--prune`, scoped to that label, and confirm `legacy-flags` is finally removed.

<br>

<details><summary>Tip</summary>

```plain
kubectl apply --help | grep -A3 "prune="
```{{exec}}

`--prune` must be given a scope — `-l` with a selector. Without one it refuses, and with the wrong one it does too much.

Note that `legacy-flags` was created *before* you added the label, so it will not carry it. Give it the label first, or prune won't consider it in scope.

</details>

<details><summary>Solution</summary>

```plain
cat > /root/app/kustomization.yaml <<'YAML'
namespace: demo
resources:
  - resources.yaml
labels:
  - pairs:
      managed-by: app-kustomize
    includeSelectors: false
YAML
```{{exec}}

```plain
kubectl kustomize /root/app | grep -E "^  name:|managed-by"
```{{exec}}

The orphan predates the label, so bring it into scope:

```plain
kubectl label configmap legacy-flags -n demo managed-by=app-kustomize --overwrite
```{{exec}}

Now apply with pruning scoped to that label:

```plain
kubectl apply -k /root/app --prune -l managed-by=app-kustomize
```{{exec}}

```plain
kubectl get configmap -n demo
```{{exec}}

</details>

<br>

<details><summary>Info: why includeSelectors: false matters</summary>

`labels:` defaults to **not** writing into `spec.selector`, which is what you want.

Its predecessor, `commonLabels`, did the opposite — it added the label to selectors as well. On an existing Deployment that is fatal: `spec.selector` is immutable, so the apply is rejected outright. `commonLabels` is now deprecated in favour of `labels:` for exactly this reason.

```plain
kubectl kustomize /root/app 2>&1 >/dev/null
```{{exec}}

Swap `labels:` for `commonLabels:` and that command will print a deprecation warning — to stderr, where a piped apply won't show it.

</details>
