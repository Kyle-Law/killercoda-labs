
Start with the behaviour that works, so the failure later is unmistakable.

Add a strategic merge patch to the overlay that sets `LOG_LEVEL=debug` on the `app` container — and **only** that. Everything else must survive: the `KEEP_ME` env var, the container's image and ports, and the `logger` sidecar.

<br>

<details><summary>Tip</summary>

```plain
kubectl kustomize /root/app/overlay
```{{exec}}

A strategic merge patch is a partial object of the same kind. You only write the fields you want to change, plus enough identity for Kustomize to find them.

</details>

<details><summary>Solution</summary>

```plain
cat > /root/app/overlay/env-patch.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  template:
    spec:
      containers:
        - name: app
          env:
            - name: LOG_LEVEL
              value: "debug"
YAML
```{{exec}}

```plain
cat > /root/app/overlay/kustomization.yaml <<'YAML'
resources:
  - ../base
patches:
  - path: env-patch.yaml
YAML
```{{exec}}

```plain
kubectl kustomize /root/app/overlay | grep -E "name: (app|logger|KEEP_ME|LOG_LEVEL)$|value:|image:"
```{{exec}}

</details>

<br>

## What the merge key bought you

The patch named exactly one container and one env var, and Kustomize used `name` as the merge key at **both** levels to find them:

- `LOG_LEVEL` changed to `debug`
- `KEEP_ME` untouched
- the `app` container kept its image and ports
- the `logger` sidecar is still there

That is more forgiving than `kubectl patch --type merge`, which is a JSON merge patch and would have **replaced** the entire `containers` list with your one-element version, deleting the sidecar and the image along with it.

Which raises the obvious question: if the key is what makes this work, what happens when the key is wrong?
