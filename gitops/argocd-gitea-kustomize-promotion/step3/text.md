
Staging has been running `v2` and it's behaving. Promote it to prod.

<br>

<details><summary>Info: what a promotion actually is here</summary>

There is no artifact moving between environments, and nothing is copied out of staging. Prod's overlay is edited to name the same tag that staging already names.

That is the whole mechanism, and it has a useful consequence: the difference between environments is always a `diff` away.

```plain
diff /root/solar-kustomize/overlays/staging/kustomization.yaml \
     /root/solar-kustomize/overlays/prod/kustomization.yaml
```{{exec}}

Before the promotion that diff includes the tag. After it, what remains is only what is *meant* to differ between the two: the target namespace, and prod's replica count.

</details>

<details><summary>Solution</summary>

```plain
cd /root/solar-kustomize
sed -i 's/newTag: v1/newTag: v2/' overlays/prod/kustomization.yaml
git -c user.email=admin@example.com -c user.name=admin commit -am "promote prod to v2"
git push
```{{exec}}

```plain
kubectl -n argocd patch application solar-prod --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
sleep 25
```{{exec}}

```plain
echo "staging: $(kubectl get deploy solar-system -n staging -o jsonpath='{.spec.template.spec.containers[0].image}')"
echo "prod:    $(kubectl get deploy solar-system -n prod    -o jsonpath='{.spec.template.spec.containers[0].image}')"
kubectl get deploy -n prod
```{{exec}}

```plain
diff /root/solar-kustomize/overlays/staging/kustomization.yaml \
     /root/solar-kustomize/overlays/prod/kustomization.yaml
```{{exec}}

</details>

<br>

## Both on v2, still different

Prod is on `v2` and still running two replicas — the promotion changed the tag and nothing else. The replica count and the namespace live in prod's overlay and were never part of what moved.

Note also what the audit trail looks like now:

```plain
cd /root/solar-kustomize && git log --oneline
```{{exec}}

Two commits, each naming one environment. "When did prod go to v2, and who did it" is answerable from the repository alone, without asking the cluster or trusting a deployment tool's own history.
