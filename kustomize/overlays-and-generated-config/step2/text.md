
One overlay proves nothing about reuse. Build a second.

Create `/root/app/overlays/prod` with a `prod-` prefix and **3 replicas**, and apply it alongside dev.

Then upgrade the application from `6.5.4` to `6.6.0` by editing exactly **one line, in one file** — and confirm both environments picked it up.

<br>

<details><summary>Tip</summary>

The prod overlay is the dev one with two values changed. Both overlays reference the same base by relative path.

For the upgrade, ask where the image belongs. It's the same in every environment, so it isn't overlay-specific — a shared change belongs in the shared place, and both overlays inherit it on their next apply.

`shopver dev-shop` and `shopver prod-shop` report the version each Deployment is actually running.

</details>

<details><summary>Solution</summary>

```plain
mkdir -p /root/app/overlays/prod
cat > /root/app/overlays/prod/kustomization.yaml <<'EOF'
resources:
  - ../../base

namePrefix: prod-

replicas:
  - name: shop
    count: 3
EOF
kubectl apply -k /root/app/overlays/prod
kubectl rollout status deployment/prod-shop --timeout=120s
kubectl get deploy -l app=shop
```{{exec}}

`dev-shop` at 2, `prod-shop` at 3, from one set of manifests. Now the upgrade — one line, in the base:

```plain
sed -i 's|podinfo:6.5.4|podinfo:6.6.0|' /root/app/base/deployment.yaml
kubectl apply -k /root/app/overlays/dev
kubectl apply -k /root/app/overlays/prod
kubectl rollout status deployment/dev-shop --timeout=120s
kubectl rollout status deployment/prod-shop --timeout=120s
```{{exec}}

```plain
shopver dev-shop
shopver prod-shop
```{{exec}}

Both on `6.6.0`, replica counts untouched. The overlays never mentioned the image, so there was nothing in either of them to update — which is the entire argument for bases: a change that is genuinely common lives in exactly one place, and environments that didn't opt out of it get it automatically.

> Each overlay still has to be applied. Kustomize renders manifests; it doesn't watch anything or push to clusters. In practice that's what the `gitops/` labs' Argo CD is for — it runs `kustomize build` for you and applies the result on every commit.

</details>
