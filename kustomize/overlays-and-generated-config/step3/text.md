
The app can display a custom message, read at startup from `PODINFO_UI_MESSAGE`. Give it one — through Kustomize, not by hand-writing a ConfigMap.

In the **base**, add a `configMapGenerator` producing a ConfigMap named `shop-config` with `ui-message=greetings from the base`, and wire it into the container as `PODINFO_UI_MESSAGE`.

Render the dev overlay before applying and look carefully at two things: the ConfigMap's **name**, and the name the Deployment **refers to**.

<br>

<details><summary>Tip</summary>

`configMapGenerator` is a top-level key in `kustomization.yaml`, a list, with `name:` and either `literals:` or `files:`.

In the container, reference it the ordinary way — `env` with `valueFrom.configMapKeyRef`, naming the ConfigMap `shop-config` exactly as the generator names it. What Kustomize does to that reference on the way out is the thing worth noticing.

```plain
kubectl kustomize /root/app/overlays/dev
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
cat > /root/app/base/kustomization.yaml <<'EOF'
resources:
  - deployment.yaml
  - service.yaml

configMapGenerator:
  - name: shop-config
    literals:
      - ui-message=greetings from the base
EOF
```{{exec}}

```plain
cat > /root/app/base/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop
spec:
  replicas: 1
  selector:
    matchLabels:
      app: shop
  template:
    metadata:
      labels:
        app: shop
    spec:
      containers:
      - name: app
        image: stefanprodan/podinfo:6.6.0
        ports:
        - containerPort: 9898
        env:
        - name: PODINFO_UI_MESSAGE
          valueFrom:
            configMapKeyRef:
              name: shop-config
              key: ui-message
EOF
kubectl kustomize /root/app/overlays/dev | grep -E "^kind:|name: dev-shop"
```{{exec}}

The ConfigMap isn't called `dev-shop-config`. It's called something like `dev-shop-config-m8t422d924` — the `dev-` prefix from the overlay, and a **hash of the ConfigMap's contents** appended by the generator.

And the Deployment's `configMapKeyRef` says that same full hashed name, even though you wrote `shop-config`. Kustomize knows `configMapKeyRef.name` is a *reference* to a ConfigMap, so it rewrote it to match what the generator actually produced. Names and the references to them cannot drift apart, because you never write the real name anywhere.

```plain
kubectl apply -k /root/app/overlays/dev
kubectl apply -k /root/app/overlays/prod
kubectl rollout status deployment/dev-shop --timeout=120s
kubectl get configmap | grep shop-config
shopmsg dev-shop
```{{exec}}

Each environment gets its own generated ConfigMap, and the app is serving the message from it.

</details>
