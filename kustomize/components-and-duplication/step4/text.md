
Components compose — but two of them can touch the same field, and Kustomize will not tell you.

A `burst` component exists for load testing, setting `replicas: 10`. Prod is going to include **both** `ha` and `burst`, and you need HA's value of **3** to be the one that survives.

**1.** Create the `burst` component.
**2.** Add it to prod alongside `ha`, arranged so the final replica count is `3`.
**3.** Then swap the two around and see what changes.

<br>

<details><summary>Solution</summary>

```plain
mkdir -p /root/app/components/burst
cat > /root/app/components/burst/kustomization.yaml <<'YAML'
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component
patches:
  - patch: |-
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: web
      spec:
        replicas: 10
YAML
```{{exec}}

Components are applied **in the order listed**, and the last one to write a field wins. So `ha` must come after `burst`:

```plain
cat > /root/app/overlays/prod/kustomization.yaml <<'YAML'
namePrefix: prod-
resources:
  - ../../base
components:
  - ../../components/monitoring
  - ../../components/burst
  - ../../components/ha
YAML
```{{exec}}

```plain
kubectl kustomize /root/app/overlays/prod | grep -E "^  replicas:"
```{{exec}}

Now reverse the last two and rebuild — changing nothing else:

```plain
cat > /tmp/reversed.yaml <<'YAML'
namePrefix: prod-
resources:
  - ../../base
components:
  - ../../components/monitoring
  - ../../components/ha
  - ../../components/burst
YAML
cp /root/app/overlays/prod/kustomization.yaml /tmp/prod-good.yaml
cp /tmp/reversed.yaml /root/app/overlays/prod/kustomization.yaml
kubectl kustomize /root/app/overlays/prod | grep -E "^  replicas:"
cp /tmp/prod-good.yaml /root/app/overlays/prod/kustomization.yaml
```{{exec}}

</details>

<br>

## Ten, then three

Same two components, same base, same everything — only the order of two lines changed, and the replica count went from 3 to 10.

There is **no warning**. Kustomize does not detect that two components write the same field; it simply applies them in sequence and keeps the last value. A conflict looks exactly like a non-conflict right up until you read the output.

That's the cost of composition: features that look independent are not, if they touch the same fields. Two habits help:

- Keep components **disjoint** — let each own fields no other component writes. Most conflicts are a design smell rather than something to order around.
- When they must overlap, treat the `components:` list as **significant**, comment it, and assert the result in CI rather than trusting the ordering to survive the next edit.

```plain
kubectl kustomize /root/app/overlays/prod | grep -E "^  replicas:"
```{{exec}}
