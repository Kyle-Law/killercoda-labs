
Argo CD and Gitea are up — [ARGO CD]({{TRAFFIC_HOST1_30080}}) (`admin` / `/root/argocd-admin-password.txt`), [GITEA]({{TRAFFIC_HOST1_30300}}) (`/root/gitea-admin-credentials.txt`).

`/root/solar-kustomize/` holds the layout this whole scenario is about:

```plain
find /root/solar-kustomize -type f | sort
```{{exec}}

One base, two overlays. Both pin `handafew/solar-system:v1`; prod additionally runs 2 replicas.

**1.** Create a `solar-kustomize` repo in Gitea and push that directory to it.
**2.** Create **two** Argo CD Applications — `solar-staging` and `solar-prod` — from the **same repo** at **different paths**, each auto-syncing into its own namespace.

<br>

<details><summary>Tip</summary>

The two Applications differ in exactly three fields: `metadata.name`, `spec.source.path`, and `spec.destination.namespace`. Everything else, `repoURL` included, is identical.

Neither namespace exists yet — `syncOptions: [CreateNamespace=true]` lets Argo CD create them.

</details>

<details><summary>Solution</summary>

```plain
curl -s -X POST -u admin:AdminPass123! \
  -H "Content-Type: application/json" \
  -d '{"name":"solar-kustomize","private":false,"auto_init":false}' \
  http://localhost:30300/api/v1/user/repos >/dev/null
```{{exec}}

```plain
cd /root/solar-kustomize
git init -b main
git add .
git -c user.email=admin@example.com -c user.name=admin commit -m "base + staging/prod overlays on v1"
git remote add origin http://admin:AdminPass123!@localhost:30300/admin/solar-kustomize.git
git push -u origin main
```{{exec}}

Now both Applications, in one manifest:

```plain
cat <<'YAML' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: solar-staging
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://gitea.gitea.svc.cluster.local:3000/admin/solar-kustomize.git
    targetRevision: main
    path: overlays/staging
  destination:
    server: https://kubernetes.default.svc
    namespace: staging
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: solar-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://gitea.gitea.svc.cluster.local:3000/admin/solar-kustomize.git
    targetRevision: main
    path: overlays/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
YAML
```{{exec}}

```plain
sleep 30
kubectl -n argocd get applications
```{{exec}}

```plain
kubectl get deploy -n staging -o wide
kubectl get deploy -n prod -o wide
```{{exec}}

</details>

<br>

## Two Applications, one source of truth

Both are `Synced` and `Healthy`, both running `v1`, and prod has the extra replica its overlay asked for. Argo CD ran `kustomize build` on each path independently — it never saw a values file, and no Kustomize CLI ran on your machine.

The important detail is that **`repoURL` is the same string in both**. There is one repository, and the environments are directories inside it. That's what makes the next two steps a promotion rather than two unrelated deployments.
