
Search for how to reference one object's name from another in Kustomize and you will find `vars`. It looks exactly right: declare a variable pointing at the Service's `metadata.name`, then use `$(VAR)` where you need it.

Try it. Add a `vars` block to the overlay that captures the backend Service's name, and change the ConfigMap value to `$(BACKEND_NAME)`.

<br>

<details><summary>Solution</summary>

The ConfigMap lives in the base, so patch it from the overlay:

```plain
cat > /root/app/prod/cfg-patch.yaml <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: appcfg
data:
  BACKEND_HOST: "$(BACKEND_NAME)"
YAML
```{{exec}}

```plain
cat > /root/app/prod/kustomization.yaml <<'YAML'
namePrefix: prod-
resources:
  - ../base
patches:
  - path: cfg-patch.yaml
vars:
  - name: BACKEND_NAME
    objref:
      kind: Service
      name: backend
      apiVersion: v1
    fieldref:
      fieldpath: metadata.name
YAML
```{{exec}}

Render it — and watch **stderr**, not just the output:

```plain
kubectl kustomize /root/app/prod 2>&1 >/dev/null
```{{exec}}

```plain
kubectl kustomize /root/app/prod | grep BACKEND_HOST
```{{exec}}

</details>

<br>

## Two things went wrong

```plain
Warning: 'vars' is deprecated. Please use 'replacements' instead.
well-defined vars that were never replaced: BACKEND_NAME
```

**First**, `vars` is deprecated. **Second, and much worse** — it didn't substitute anything. The rendered ConfigMap contains the literal string `$(BACKEND_NAME)`, so the app now tries to resolve a hostname with brackets in it.

And notice where that warning went: **stderr**. In a pipeline like `kubectl apply -k` or an Argo CD sync, nobody sees it. The render "succeeds", the apply "succeeds", and the config is now worse than when you started.

```plain
kubectl apply -k /root/app/prod
sleep 15
kubectl logs -l app=frontend --tail=3
```{{exec}}

That is the failure mode to remember: **`vars` does not error when it fails to resolve.** It leaves the placeholder in place and moves on.
