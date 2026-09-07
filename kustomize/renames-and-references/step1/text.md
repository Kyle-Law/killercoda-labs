
Deploy the base as-is and confirm the app is healthy:

```plain
kubectl apply -k /root/app/base
kubectl wait --for=condition=Available deploy/frontend deploy/backend --timeout=120s
```{{exec}}

```plain
kubectl logs -l app=frontend --tail=3
```{{exec}}

`OK reached backend`. Now do the thing that breaks it.

Create an overlay at `/root/app/prod` that pulls in the base and applies `namePrefix: prod-`, then apply it.

<br>

<details><summary>Tip</summary>

```plain
kubectl kustomize /root/app/prod
```{{exec}}

Render it and read the output *before* applying — the bug is visible there if you know what to look for.

</details>

<details><summary>Solution</summary>

```plain
mkdir -p /root/app/prod
cat > /root/app/prod/kustomization.yaml <<'YAML'
namePrefix: prod-
resources:
  - ../base
YAML
```{{exec}}

Look at what the rename did and didn't touch:

```plain
kubectl kustomize /root/app/prod | grep -E "^  name:|BACKEND_HOST|configMapRef" -A1
```{{exec}}

Apply it:

```plain
kubectl apply -k /root/app/prod
kubectl wait --for=condition=Available deploy/prod-frontend --timeout=120s
```{{exec}}

Everything applied cleanly. Now read the logs:

```plain
sleep 15
kubectl logs -l app=frontend --tail=5 | sort | uniq -c
```{{exec}}

</details>

<br>

## What just happened

Kustomize rewrote every reference it **understands**:

- the Service is now `prod-backend`
- the ConfigMap is now `prod-appcfg`
- the Deployment's `configMapRef.name` was updated to `prod-appcfg` — Kustomize knows that field names a ConfigMap

And it left the one that matters untouched:

```yaml
data:
  BACKEND_HOST: "backend"     # still the old name
```

That's a string. Kustomize has no way to know it's a hostname, so the `prod-frontend` Pod is dutifully resolving `backend` — a Service that no longer exists under that name.

**No error anywhere.** The manifests are valid, the objects exist, the Deployment is Available. Only the logs know.
