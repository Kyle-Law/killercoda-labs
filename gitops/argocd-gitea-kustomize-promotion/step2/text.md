
A new version, `v2`, is ready for staging. There is no CLI flag for this and nothing to click — the deployed version is whatever the overlay says, so promoting means **editing the overlay and pushing**.

Move staging to `v2`, leaving prod alone.

<br>

<details><summary>Tip</summary>

```plain
cat /root/solar-kustomize/overlays/staging/kustomization.yaml
```{{exec}}

The `images:` transformer is what pins the tag. Change it there, commit, push — Argo CD is already watching.

</details>

<details><summary>Solution</summary>

```plain
cd /root/solar-kustomize
sed -i 's/newTag: v1/newTag: v2/' overlays/staging/kustomization.yaml
git -c user.email=admin@example.com -c user.name=admin commit -am "promote staging to v2"
git push
```{{exec}}

Argo CD polls roughly every three minutes; nudge it rather than waiting:

```plain
kubectl -n argocd patch application solar-staging --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
sleep 25
```{{exec}}

```plain
echo "staging: $(kubectl get deploy solar-system -n staging -o jsonpath='{.spec.template.spec.containers[0].image}')"
echo "prod:    $(kubectl get deploy solar-system -n prod    -o jsonpath='{.spec.template.spec.containers[0].image}')"
```{{exec}}

</details>

<br>

## One commit, one environment

Staging is on `v2`. Prod is still on `v1`, and its Application never went `OutOfSync` — nothing it reads changed.

That's the property worth noticing: both Applications watch the same repository, but each only reconciles the subtree under its own `path`. A commit that touches `overlays/staging/` is invisible to `solar-prod`, even though the two share a `repoURL` and a branch.

Which is exactly what you want from a promotion: the change is real, recorded in Git, and **scoped**.
