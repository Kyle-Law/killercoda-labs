
Add a third resource, commit, push — watch it show up. Then take it back out, commit, push — watch it disappear on its own.

```
cat > /root/solar-system-app/configmap.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: solar-system-extra
data:
  note: "should get pruned"
EOF
cd /root/solar-system-app
git -c user.email=admin@example.com -c user.name=admin add configmap.yaml
git -c user.email=admin@example.com -c user.name=admin commit -m "add extra configmap"
git push origin main
```{{exec}}

Confirm it landed (`kubectl -n solar-system get configmap solar-system-extra`), then remove it the same way you added it — delete the file, commit, push. Predict what happens to the live ConfigMap before you check.

<br>

<details><summary>Tip</summary>

Nothing here runs `kubectl delete`. The only instruction is a `git rm`, a commit, and a push — same three commands you've used all lab for every other change.

</details>

<details><summary>Solution</summary>

```
cd /root/solar-system-app
git rm configmap.yaml
git -c user.email=admin@example.com -c user.name=admin commit -m "remove extra configmap"
git push origin main
```{{exec}}

```
kubectl -n solar-system get configmap solar-system-extra
```{{exec}}

`NotFound`, within seconds of the push — the webhook fired, Argo CD compared the live cluster against a Git tree that no longer mentions this ConfigMap at all, and `prune: true` (set back in step 1) turned "no longer declared" into "delete it," the same automatic way `selfHeal` turned "doesn't match declared" into "revert it." Between the two, the cluster can only ever drift from Git for as long as one webhook round-trip takes — add something outside Git and it's gone; remove something from Git and its live copy follows.

</details>
