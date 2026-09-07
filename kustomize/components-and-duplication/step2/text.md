
Define the monitoring patch **once**, as a Component, and have both overlays pull it in.

A Component is a kustomization with a different `kind`. It can carry patches, resources, generators — anything an overlay can — but it isn't rendered on its own. It's applied *into* whatever overlay includes it.

Create `/root/app/components/monitoring`, move the patch there, and change both overlays to reference it. The rendered output for both environments must be **unchanged**.

<br>

<details><summary>Tip</summary>

A Component's `kustomization.yaml` needs two fields an overlay doesn't:

```yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component
```

And overlays include it under `components:`, not `resources:`.

</details>

<details><summary>Solution</summary>

Capture the current output first, so you can prove nothing changed:

```plain
kubectl kustomize /root/app/overlays/prod > /tmp/prod-before.yaml
kubectl kustomize /root/app/overlays/staging > /tmp/staging-before.yaml
```{{exec}}

```plain
mkdir -p /root/app/components/monitoring
mv /root/app/overlays/prod/monitoring-patch.yaml /root/app/components/monitoring/patch.yaml
rm /root/app/overlays/staging/monitoring-patch.yaml
```{{exec}}

```plain
cat > /root/app/components/monitoring/kustomization.yaml <<'YAML'
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component
patches:
  - path: patch.yaml
YAML
```{{exec}}

```plain
for e in staging prod; do
cat > /root/app/overlays/$e/kustomization.yaml <<YAML
namePrefix: $e-
resources:
  - ../../base
components:
  - ../../components/monitoring
YAML
done
```{{exec}}

Prove the render is identical:

```plain
kubectl kustomize /root/app/overlays/prod    > /tmp/prod-after.yaml
kubectl kustomize /root/app/overlays/staging > /tmp/staging-after.yaml
diff /tmp/prod-before.yaml /tmp/prod-after.yaml       && echo "prod: unchanged"
diff /tmp/staging-before.yaml /tmp/staging-after.yaml && echo "staging: unchanged"
```{{exec}}

</details>

<br>

<details><summary>Info: what happens if you use resources: by mistake</summary>

Try it — this is one of the rare Kustomize mistakes that fails loudly:

```plain
sed -i 's/^components:/resources:/' /root/app/overlays/staging/kustomization.yaml
kubectl kustomize /root/app/overlays/staging 2>&1 | head -2
sed -i '0,/^resources:/! s/^resources:/components:/' /root/app/overlays/staging/kustomization.yaml
```{{exec}}

```plain
expected kind != 'Component'
```

Kustomize refuses to treat a Component as a plain resource. Restore it before moving on:

```plain
cat > /root/app/overlays/staging/kustomization.yaml <<'YAML'
namePrefix: staging-
resources:
  - ../../base
components:
  - ../../components/monitoring
YAML
kubectl kustomize /root/app/overlays/staging >/dev/null && echo "restored"
```{{exec}}

</details>

<br>

Now the port lives in exactly one file, and both environments follow it.
