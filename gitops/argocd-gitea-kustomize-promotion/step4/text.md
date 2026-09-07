
Everything so far behaved because each commit touched exactly one overlay. Now touch the thing they share.

A readiness probe tweak goes into `base/deployment.yaml` — a small, sensible, entirely reasonable change. Push it, and watch where it lands.

<br>

<details><summary>Solution</summary>

```plain
cd /root/solar-kustomize
sed -i 's/periodSeconds: 5/periodSeconds: 17/' base/deployment.yaml
grep -A5 readinessProbe base/deployment.yaml
```{{exec}}

```plain
git -c user.email=admin@example.com -c user.name=admin commit -am "tune readiness probe interval"
git push
```{{exec}}

```plain
kubectl -n argocd patch application solar-staging --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
kubectl -n argocd patch application solar-prod --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
sleep 30
```{{exec}}

```plain
for ns in staging prod; do
  echo "$ns: periodSeconds=$(kubectl get deploy solar-system -n $ns -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.periodSeconds}')"
done
```{{exec}}

</details>

<br>

## Both. Immediately.

One commit, no promotion, and prod changed at the same moment staging did.

Nothing here is broken — this is exactly what inheritance means, and it's the reason a base exists. But it does mean the repository contains two very different kinds of change, which look identical in `git log`:

| Change | Reaches |
|---|---|
| `overlays/staging/...` | staging only |
| `overlays/prod/...` | prod only |
| **`base/...`** | **every environment, at once** |

With `automated` sync on both Applications, a base commit is a production deploy that never went through staging — and the commit message will say something like "tune readiness probe interval".

<details><summary>Info: what teams actually do about it</summary>

The mitigations are all about making that third row visible or slow:

- **Pin overlays to a revision instead of a branch.** `targetRevision` can be a tag or commit SHA, so prod moves only when someone repoints it — the base can change freely without reaching prod.
- **Split the repository.** Base in one repo, environments in another, with the environment repo referencing a versioned base. Promotion becomes a version bump, and there is no path that touches prod implicitly.
- **Take `automated` off prod.** Keep it on staging, and require a manual sync for prod. Argo CD will still show prod as `OutOfSync` the moment base changes — the difference is that someone has to agree.
- **Guard `base/` in review.** A CODEOWNERS rule on that directory is the cheapest of the four and catches the accidental case, which is most of them.

Try the third one — it's one field:

```plain
kubectl -n argocd patch application solar-prod --type json \
  -p '[{"op":"remove","path":"/spec/syncPolicy/automated"}]'
kubectl -n argocd get application solar-prod -o jsonpath='{.spec.syncPolicy}{"\n"}'
```{{exec}}

Prod will now go `OutOfSync` on a base change and wait, instead of deploying.

</details>
