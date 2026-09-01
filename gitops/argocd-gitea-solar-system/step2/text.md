
`/root/solar-system-app/` has the same two manifests from the last lab — a Deployment pinned to `v3`, a NodePort Service on `30090`. No repo exists for them yet.

Create a repository named `solar-system` in Gitea — public, don't auto-initialize it — then turn `/root/solar-system-app/` into a Git repo and push it there.

<br>

<details><summary>Tip</summary>

The **+** menu in Gitea's top nav has **New Repository**. Leave `Initialize Repository` unchecked — you're pushing an existing repo in, not merging with one Gitea creates for you, and an unrelated initial commit on Gitea's side would just conflict with yours.

Gitea's clone URL is `http://<host>:30300/admin/solar-system.git`, but from *this* terminal — not your browser — `localhost` reaches the same place `30300` does in your browser, more directly.

</details>

<details><summary>Solution</summary>

Create the repo either through the UI (**+ → New Repository**, name `solar-system`, public, no initialize), or from here:

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

[VIEW THE REPO]({{TRAFFIC_HOST1_30300}}/admin/solar-system) — both files, one commit, entirely yours.

</details>
