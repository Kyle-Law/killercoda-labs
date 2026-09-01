
`solar-system` is `Synced`/`Healthy` on `v3`. Right now, Argo CD only finds out about a new commit on its own poll — the same staleness from the last lab. Fix that at the source: add a webhook in Gitea's repo settings that fires on every push, pointed at Argo CD.

Then push a real change — bump the image to `v9` — and time how long `Sync Status` takes to move off `v3`'s commit. No `--refresh`, no clicking anything.

<br>

<details><summary>Tip</summary>

Repo → **Settings** → **Webhooks** → **Add Webhook** → **Gitea**. The target is the same kind of address as always for anything running *inside* this cluster calling something else inside it: `argocd-server`'s in-cluster Service DNS name, not `localhost:30080`. Argo CD's webhook receiver listens at `/api/webhook` on that address. Content type `application/json`, trigger on `Push Events`.

`kubectl get application solar-system -n argocd -o jsonpath='{.status.sync.revision}'` — compare against `git -C /root/solar-system-app log --oneline -1` right after pushing.

</details>

<details><summary>Solution</summary>

```
curl -X POST -u admin:AdminPass123! http://localhost:30300/api/v1/repos/admin/solar-system/hooks \
  -H "Content-Type: application/json" \
  -d '{"type":"gitea","config":{"url":"http://argocd-server.argocd.svc.cluster.local/api/webhook","content_type":"json"},"events":["push"],"active":true}'
```{{exec}}

```
cd /root/solar-system-app
sed -i 's/solar-system:v3/solar-system:v9/' deployment.yaml
git -c user.email=admin@example.com -c user.name=admin commit -am "bump to v9"
git push origin main
```{{exec}}

```
kubectl get application solar-system -n argocd -o jsonpath='{.status.sync.status} {.status.sync.revision}{"\n"}'
git -C /root/solar-system-app log --oneline -1
```{{exec}}

Run that last check a couple of times a few seconds apart — the revision catches up to `git log`'s within seconds, and `syncPolicy.automated` (set back in step 1) means it doesn't stop at just noticing: it syncs on its own too.

Two things had to line up for that webhook to actually land, both already true here:

- Gitea refuses, by default, to let a webhook call an internal address at all — basic SSRF protection against exactly this kind of target. This Gitea was started with `security.ALLOWED_HOST_LIST=private,loopback`, which is what allows a webhook pointed at `argocd-server.argocd.svc.cluster.local` to go out in the first place. Delete that setting and the delivery fails silently from Argo CD's side — Gitea just never sends it, and its own Pod logs are the only place that says why.
- The webhook payload describes the repo using whatever Gitea's own `ROOT_URL` is configured as — here, `http://gitea.gitea.svc.cluster.local:3000/...`, deliberately set to match this Application's `repoURL` exactly. Argo CD matches an incoming webhook to an Application by comparing that URL string, not by asking DNS whether they point at the same place. Had Gitea kept the browser-facing `http://localhost:30300/` as its `ROOT_URL` instead, the webhook would arrive, Argo CD would log receiving it, and still do nothing — logged and ignored, because the URL in the payload never matches the one on the Application.

</details>
