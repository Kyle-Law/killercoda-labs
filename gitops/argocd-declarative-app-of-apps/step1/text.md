
`gitops/argocd-declarative-app-of-apps/apps-chart/` in this same repo ([killercoda-labs](https://github.com/Kyle-Law/killercoda-labs)) is a tiny Helm chart. Its only template, `templates/applications.yaml`, ranges over `.Values.environments` and renders one Argo CD `Application` per entry — each sourcing the real `podinfo` chart, with its own `replicaCount` and `ui.color`.

Write the parent yourself: an `Application` object, `kubectl apply`'d from a file you create — no `argocd app create`. Point it at that chart, and pass it two environments as Helm values: `dev` (`replicaCount: 1`, color `34577c`) and `staging` (`replicaCount: 2`, color `f2b632`).

<br>

<details><summary>Tip</summary>

The source is a plain GitHub repo, same shape as any other `gitops/` lab that points at its own manifests: `repoURL: https://github.com/Kyle-Law/killercoda-labs.git`, `path: gitops/argocd-declarative-app-of-apps/apps-chart`, `targetRevision: HEAD`.

Values for a Helm-sourced Application go under `spec.source.helm.valuesObject` — a real YAML object, structured exactly like a `values.yaml` file would be, not a flat list of `--set` strings. The chart expects `environments` to be a list, each entry with `name`, `replicaCount`, and `color`.

Give the parent itself `syncPolicy.automated` with `prune: true` and `selfHeal: true`, plus `CreateNamespace=true` — each child needs its own namespace created for it, same as the parent needed for itself.

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
```{{exec}}

Three: `app-of-apps`, `podinfo-dev`, `podinfo-staging` — all `Synced`/`Healthy` without a single `sync` command run against any of them.

```
kubectl -n podinfo-dev get deployment podinfo-dev -o jsonpath='replicas: {.spec.replicas}{"\n"}'
kubectl -n podinfo-staging get deployment podinfo-staging -o jsonpath='replicas: {.spec.replicas}{"\n"}'
```{{exec}}

`1` and `2` — the exact values passed through `valuesObject`, landing in two real Helm releases' worth of Kubernetes resources, each in its own namespace, from one file you wrote.

</details>
