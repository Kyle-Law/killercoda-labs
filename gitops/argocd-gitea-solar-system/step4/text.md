
`solar-system` is `Synced`/`Healthy` on `v3`, sourced from your own Gitea. This time, make the change the way it's actually supposed to happen: edit the file, commit, push — no `kubectl` involved at all.

```
cd /root/solar-system-app
sed -i 's/solar-system:v3/solar-system:v9/' deployment.yaml
git -c user.email=admin@example.com -c user.name=admin commit -am "bump to v9"
git push origin main
```{{exec}}

Immediately after that push finishes, check the Application's `Sync Status` — from the terminal or the UI, either one. Predict what it says before you look. Then find the button that makes it actually check, and watch the status change.

<br>

<details><summary>Tip</summary>

```
kubectl get application solar-system -n argocd -o jsonpath='{.status.sync.status} {.status.sync.revision}{"\n"}'
```{{exec}}

Compare that revision against `git log --oneline -1` in `/root/solar-system-app`. Argo CD's `Sync Status` is a cached answer from the last time it looked — pushing to Git doesn't push a notification back. In the UI, the button that forces a fresh look is **Refresh**, separate from **Sync**.

</details>

<details><summary>Solution</summary>

```
kubectl get application solar-system -n argocd -o jsonpath='{.status.sync.status} {.status.sync.revision}{"\n"}'
git -C /root/solar-system-app log --oneline -1
```{{exec}}

Different commit hashes — Argo CD is still reporting the *previous* sync as current, because nothing has told it to look again.

```
argocd login localhost:30080 --username admin --password "$(cat /root/argocd-admin-password.txt)" --plaintext
argocd app get solar-system --refresh
```{{exec}}

Now it matches — `OutOfSync`, against the new commit. `--refresh` is exactly what the UI's **Refresh** button does: look at Git again, right now, instead of waiting for the next scheduled check.

```
argocd app sync solar-system
```{{exec}}

```
kubectl get deployment solar-system -n solar-system -o jsonpath='{.spec.template.spec.containers[0].image}'
```{{exec}}

`v9` — a change that started as a text edit on this filesystem, went through a real `git push`, and ended up running in the cluster, with Argo CD as the only thing that ever touched the live Deployment directly.

</details>
