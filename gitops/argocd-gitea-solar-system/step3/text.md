
Your repo exists in Gitea. Now create the Argo CD Application that deploys from it — in the UI, **+ NEW APP**:

- **Application Name:** `solar-system`
- **Project:** `default`
- **Sync Policy:** `Manual`
- **Repository URL:** the address `argocd-repo-server` — running *inside this cluster* — needs to resolve. Not `localhost:30300`, not the address in your browser tab: work out the in-cluster Service DNS name for `gitea` in namespace `gitea`, on port `3000`.
- **Path:** `.`
- **Cluster URL:** `https://kubernetes.default.svc`
- **Namespace:** `solar-system` (enable `Create Namespace`)

Create it, sync it, confirm both Pods `Healthy`, then view the app.

<br>

<details><summary>Tip</summary>

Kubernetes Service DNS follows one pattern everywhere in the cluster: `<service-name>.<namespace>.svc.cluster.local`. You already know the service is called `gitea`, in the `gitea` namespace, on port `3000` — from step 1.

Argo CD needs the full clone URL, same shape as any Git host: `http://<host>:<port>/<owner>/<repo>.git`.

</details>

<details><summary>Solution</summary>

**Repository URL:** `http://gitea.gitea.svc.cluster.local:3000/admin/solar-system.git`

With the app created and synced from the UI:

```
kubectl get pods -n solar-system
kubectl get application solar-system -n argocd -o jsonpath='{.status.sync.status} {.status.health.status}{"\n"}'
```{{exec}}

`Synced Healthy`, both Pods `Running` — deployed entirely from a repo that only exists in *this* cluster, using its Service DNS the same way any other in-cluster client would.

[VIEW THE APP]({{TRAFFIC_HOST1_30090}})

</details>
