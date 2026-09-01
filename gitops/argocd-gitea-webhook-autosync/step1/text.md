
Argo CD and Gitea are both installed and already on NodePort — [ARGO CD]({{TRAFFIC_HOST1_30080}}) (`admin` / `/root/argocd-admin-password.txt`), [GITEA]({{TRAFFIC_HOST1_30300}}) (`/root/gitea-admin-credentials.txt`). `/root/solar-system-app/` has the same Deployment and Service from the earlier lab, pinned to `v3`.

Two things this time, neither through the UI:

1. Create a `solar-system` repo in Gitea (public, no auto-init) and push `/root/solar-system-app/` to it.
2. Create the Argo CD `Application` yourself, declaratively — a YAML manifest, `kubectl apply`'d — with `syncPolicy.automated` set from the moment it's created: `prune: true`, `selfHeal: true`. No `argocd app create`, no clicking **Sync** ever, starting now.

<br>

<details><summary>Tip</summary>

The repo-push step is identical to the last lab — Gitea's clone URL from this terminal is `http://localhost:30300/admin/solar-system.git`.

For the Application, the shape is the same `Application` object from before, but two fields matter that a UI-created one might not have set: under `spec.syncPolicy`, an `automated` block with `prune: true` and `selfHeal: true` — and `spec.syncPolicy.syncOptions` still needs `CreateNamespace=true`, since nothing's manually creating `solar-system` this time either.

</details>

<details><summary>Solution</summary>

```
curl -X POST -u admin:AdminPass123! http://localhost:30300/api/v1/user/repos \
  -H "Content-Type: application/json" \
  -d '{"name":"solar-system","private":false,"auto_init":false}'
```{{exec}}

```
cd /root/solar-system-app
git init
git add .
git -c user.email=admin@example.com -c user.name=admin commit -m "initial solar-system manifests"
git remote add origin http://admin:AdminPass123!@localhost:30300/admin/solar-system.git
git push -u origin main
```{{exec}}

```
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: solar-system
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://gitea.gitea.svc.cluster.local:3000/admin/solar-system.git
    targetRevision: main
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: solar-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF
```{{exec}}

```
kubectl get application solar-system -n argocd -o jsonpath='{.status.sync.status} {.status.health.status}{"\n"}'
```{{exec}}

`Synced Healthy` within a few seconds of applying it — no `argocd app create`, no `argocd app sync`, nothing clicked. `automated` sync means Argo CD compares against Git on its own timer and acts on what it finds, from the very first reconcile.

</details>
