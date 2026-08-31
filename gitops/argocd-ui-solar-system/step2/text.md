
In the UI, click **+ NEW APP** and fill in:

- **Application Name:** `solar-system`
- **Project:** `default`
- **Sync Policy:** `Manual`
- **Repository URL:** `https://github.com/Kyle-Law/killercoda-labs.git`
- **Path:** `gitops/argocd-ui-solar-system/manifests`
- **Cluster URL:** `https://kubernetes.default.svc`
- **Namespace:** `solar-system`

Before you hit **CREATE**, find the checkbox for creating the destination namespace automatically — `solar-system` doesn't exist yet, and without it the first sync fails outright. Then create the app and sync it.

Once both Pods are `Healthy`, look at the manifest's own `service.yaml` — the app's Service is already `NodePort`, on `30090`, committed straight into the source. Nothing left to expose by hand this time; view it.

<br>

<details><summary>Tip</summary>

The checkbox is under the **SYNC POLICY** section of the create-app form — `Create Namespace` is one of the options once you expand it. If you already clicked Create and hit the namespace error, click into the app and use **DETAILS → EDIT** to turn it on retroactively, no need to start over.

</details>

<details><summary>Solution</summary>

With the app created (namespace-create option on) and synced from the UI, confirm from the terminal:

```
kubectl get pods -n solar-system
kubectl get svc solar-system -n solar-system
```{{exec}}

Both Pods `Running`, `1/1` — and the Service already shows `80:30090/TCP`, no patch needed. Unlike `argocd-server`'s Service in step 1, this one's `NodePort` type is part of what Argo CD applied, not something bolted on afterward.

[VIEW THE APP]({{TRAFFIC_HOST1_30090}})

A live, running solar system animation — created without ever running `argocd app create`.

</details>
