
`replacements` is what `vars` was trying to be. Instead of declaring a variable and hoping something substitutes it, you state explicitly: **take this field from this object, and write it into these fields on those objects.**

Replace the `vars` block with a `replacements` block that copies the backend Service's `metadata.name` into the ConfigMap's `BACKEND_HOST`, and drop the `$(...)` placeholder from the patch.

<br>

<details><summary>Info: why this one resolves and vars didn't</summary>

`replacements` runs as a transformer over the built resource graph, **after** name prefixes are applied. So the source it reads is already `prod-backend`, and the target it writes is a concrete field path it either finds or fails on.

`vars` was a build-time substitution that only applied in a limited set of fields, which is exactly why it so often silently missed.

</details>

<details><summary>Solution</summary>

Put a real value back in the patch — it will be overwritten, but it should be valid on its own:

```plain
cat > /root/app/prod/cfg-patch.yaml <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: appcfg
data:
  BACKEND_HOST: "placeholder"
YAML
```{{exec}}

```plain
cat > /root/app/prod/kustomization.yaml <<'YAML'
namePrefix: prod-
resources:
  - ../base
patches:
  - path: cfg-patch.yaml
replacements:
  - source:
      kind: Service
      name: backend
      fieldPath: metadata.name
    targets:
      - select:
          kind: ConfigMap
          name: appcfg
        fieldPaths:
          - data.BACKEND_HOST
YAML
```{{exec}}

Check the render before applying:

```plain
kubectl kustomize /root/app/prod | grep -E "BACKEND_HOST|^  name: prod-backend"
```{{exec}}

```plain
kubectl apply -k /root/app/prod
kubectl rollout status deploy/prod-frontend --timeout=120s
```{{exec}}

```plain
sleep 15
kubectl logs -l app=frontend --tail=5 | sort | uniq -c
```{{exec}}

</details>

<br>

> Note that `source` selects the Service by its **original** name, `backend` — you write selectors against the resources as they exist in the base, and Kustomize resolves them against the built output. The value it copies is the final, prefixed one.
