
Add a third environment, `prod` — `replicaCount: 3`, color `9d174d`. Nothing in `apps-chart/` changes; only `/root/app-of-apps.yaml`, the file you already own.

<br>

<details><summary>Tip</summary>

Edit the `environments` list in `/root/app-of-apps.yaml` directly and `kubectl apply` it again — same file, same command as step 1, just a longer list this time. Argo CD re-templates the whole chart from the new values and reconciles whatever's different; entries that didn't change don't get touched.

</details>

<details><summary>Solution</summary>

```
cat > /root/app-of-apps.yaml <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/Kyle-Law/killercoda-labs.git
    targetRevision: HEAD
    path: gitops/argocd-declarative-app-of-apps/apps-chart
    helm:
      valuesObject:
        environments:
        - name: dev
          replicaCount: 1
          color: "34577c"
        - name: staging
          replicaCount: 2
          color: "f2b632"
        - name: prod
          replicaCount: 3
          color: "9d174d"
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF
kubectl apply -f /root/app-of-apps.yaml
```{{exec}}

```
argocd app list --core
kubectl -n podinfo-prod get deployment podinfo-prod -o jsonpath='replicas: {.spec.replicas}{"\n"}'
```{{exec}}

A fourth Application, `podinfo-prod`, `Synced`/`Healthy` with `3` replicas — and `podinfo-dev`/`podinfo-staging` never re-synced, because nothing about their rendered output changed.

</details>
