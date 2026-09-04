
`/root/app` holds a base and one overlay:

```plain
find /root/app -type f
cat /root/app/base/kustomization.yaml /root/app/overlays/dev/kustomization.yaml
```{{exec}}

Render the overlay **without applying it** — note that this needs no cluster at all, and works fine if you break the connection to one:

```plain
kubectl kustomize /root/app/overlays/dev
```{{exec}}

`base/deployment.yaml` says `name: shop`, yet what came out says `dev-shop`. Nothing generated a new file; the base is untouched on disk.

**Two tasks.** Apply the dev overlay, then make dev run **2 replicas** — without editing anything under `base/`.

<br>

<details><summary>Tip</summary>

`kubectl apply -k <dir>` builds and applies in one go; `kubectl kustomize <dir>` just prints.

The overlay's `resources: [../../base]` is a *reference*, not a copy — everything else in that file describes what to change about what it references. For replica counts specifically there's a dedicated field that doesn't require writing a patch:

```plain
kubectl explain --help >/dev/null 2>&1; grep -n "replicas" /root/app/base/deployment.yaml
```{{exec}}

The `replicas:` entry in a kustomization takes a `name:` (the resource's name **in the base**, before any prefix) and a `count:`.

</details>

<details><summary>Solution</summary>

```plain
kubectl apply -k /root/app/overlays/dev
kubectl get deploy,svc -l app=shop
```{{exec}}

Now add the replica override to the *overlay*:

```plain
cat > /root/app/overlays/dev/kustomization.yaml <<'EOF'
resources:
  - ../../base

namePrefix: dev-

replicas:
  - name: shop
    count: 2
EOF
kubectl apply -k /root/app/overlays/dev
kubectl rollout status deployment/dev-shop --timeout=120s
kubectl get deployment dev-shop
```{{exec}}

`2/2`, while the base still says `replicas: 1`:

```plain
grep replicas /root/app/base/deployment.yaml
```{{exec}}

Two things to take from this. First, `name: shop` in that `replicas:` entry refers to the resource as the **base** names it — matching happens before `namePrefix` is applied, not after. Second, the overlay never restates the image, the ports, the labels or the Service; it records only the delta. A second environment is a few lines, not a second copy of the app.

</details>
