
Monitoring is shared. Now add a feature that **isn't**.

Create a second Component, `ha`, that raises `replicas` to `3`, and apply it to **prod only**. Staging keeps monitoring and stays at 1 replica.

<br>

<details><summary>Solution</summary>

```plain
mkdir -p /root/app/components/ha
cat > /root/app/components/ha/kustomization.yaml <<'YAML'
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component
patches:
  - patch: |-
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: web
      spec:
        replicas: 3
YAML
```{{exec}}

```plain
cat > /root/app/overlays/prod/kustomization.yaml <<'YAML'
namePrefix: prod-
resources:
  - ../../base
components:
  - ../../components/monitoring
  - ../../components/ha
YAML
```{{exec}}

```plain
for e in staging prod; do
  echo "--- $e ---"
  kubectl kustomize /root/app/overlays/$e | grep -E "^  replicas:|prometheus.io/port"
done
```{{exec}}

</details>

<br>

## What you just avoided

Without components, "prod gets monitoring and HA, staging gets monitoring only" needs an overlay per combination. Add a third feature and it's eight directories — most of them copies of each other.

With components it's a **list**. Each feature is defined once, and an environment is the set of features it opts into:

```yaml
components:
  - ../../components/monitoring
  - ../../components/ha
```

Adding a fourth environment that wants monitoring and HA is now three lines, not a directory tree. And a change to HA is one file, whoever uses it.
