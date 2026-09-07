
The ConfigMap case was easy because the whole field value *was* the hostname. Real manifests bury addresses inside longer strings — connection strings, flags, URLs.

Add a second container argument to the frontend that carries the backend address inline, and make `replacements` fix that too.

**1.** Patch the frontend Deployment so its container gets an extra arg: `--upstream=backend`
**2.** Extend `replacements` so that arg tracks the rename as well — it should end up `--upstream=prod-backend`, with the `--upstream=` part intact.

<br>

<details><summary>Tip</summary>

A replacement target normally overwrites the **whole** field. To rewrite part of a string, `options` lets you split it:

```yaml
options:
  delimiter: "="
  index: 1
```

That splits the existing value on `=` and replaces only the segment at that index.

To address one container in a list, field paths support a key selector:

```plain
spec.template.spec.containers.[name=frontend].args.0
```

</details>

<details><summary>Solution</summary>

```plain
cat > /root/app/prod/deploy-patch.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  template:
    spec:
      containers:
        - name: frontend
          args:
            - "--upstream=backend"
YAML
```{{exec}}

```plain
cat > /root/app/prod/kustomization.yaml <<'YAML'
namePrefix: prod-
resources:
  - ../base
patches:
  - path: cfg-patch.yaml
  - path: deploy-patch.yaml
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
      - select:
          kind: Deployment
          name: frontend
        fieldPaths:
          - spec.template.spec.containers.[name=frontend].args.0
        options:
          delimiter: "="
          index: 1
YAML
```{{exec}}

```plain
kubectl kustomize /root/app/prod | grep -E "upstream|BACKEND_HOST"
```{{exec}}

```plain
kubectl apply -k /root/app/prod
kubectl rollout status deploy/prod-frontend --timeout=120s
```{{exec}}

</details>

<br>

<details><summary>Info: the rule worth remembering</summary>

Kustomize rewrites references through **name reference transformers** — a built-in list of field paths it knows point at other objects (`configMapRef.name`, `serviceAccountName`, `spec.rules[].http.paths[].backend.service.name`, and so on).

Anything outside that list is an opaque string, and no amount of `namePrefix` will touch it. Those are exactly the places you need `replacements` — and exactly the places nothing will warn you about.

The practical habit: after adding a `namePrefix` or `nameSuffix`, grep the rendered output for the old name.

```plain
kubectl kustomize /root/app/prod | grep -n "backend" | grep -v "prod-backend"
```{{exec}}

Anything that comes back is a reference the rename left behind.

</details>
