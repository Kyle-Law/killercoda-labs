
Remove `dev` from the list entirely — down to `staging` and `prod`. Re-apply, no special flags. Before checking anything, predict three separate outcomes: does the `podinfo-dev` **Application object** disappear? Does its Deployment and Service disappear? Does the `podinfo-dev` **namespace** disappear?

<br>

<details><summary>Tip</summary>

No `--prune` flag needed anywhere this time — unlike a manually-synced app-of-apps, this parent already has `syncPolicy.automated.prune: true` from step 1. Its own next automated reconcile is the thing that notices `dev` is gone from the rendered output and removes it, on its own timer.

Check `kubectl get application podinfo-dev -n argocd -o jsonpath='{.metadata.finalizers}'` while it still exists — the chart sets `resources-finalizer.argocd.argoproj.io` on every child it renders, for exactly this moment.

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
        - name: staging
          replicaCount: 4
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
kubectl get application podinfo-dev -n argocd
kubectl -n podinfo-dev get deploy,svc
kubectl get ns podinfo-dev
```{{exec}}

The Application object: gone, once the parent's next automated sync catches up. Its Deployment and Service: gone too — the finalizer waited for those before letting the Application itself finish deleting. The namespace: still there. `CreateNamespace=true` only ever runs forward; nothing about pruning a child ever removes the namespace it landed in.

</details>
