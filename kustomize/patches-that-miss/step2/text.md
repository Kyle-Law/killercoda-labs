
Now make the mistake everyone makes.

The base container is called `app`. Write a patch that targets **`aap`** instead — a single transposed character — and give it an image that doesn't exist: `nginx:1.99-DOESNOTEXIST`.

Then build it, and predict what you'll get before you look.

<br>

<details><summary>Solution</summary>

```plain
cat > /root/app/overlay/typo-patch.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  template:
    spec:
      containers:
        - name: aap
          image: nginx:1.99-DOESNOTEXIST
YAML
```{{exec}}

```plain
cat > /root/app/overlay/kustomization.yaml <<'YAML'
resources:
  - ../base
patches:
  - path: env-patch.yaml
  - path: typo-patch.yaml
YAML
```{{exec}}

Build it. Note the exit status and anything on stderr:

```plain
kubectl kustomize /root/app/overlay >/dev/null; echo "exit=$?"
kubectl kustomize /root/app/overlay 2>&1 >/dev/null; echo "(nothing above = no warning)"
```{{exec}}

Now count the containers:

```plain
kubectl kustomize /root/app/overlay | grep -E "^        name: |image:"
```{{exec}}

</details>

<br>

## Three containers

The build succeeded. There was no warning. And the Deployment now has a **third** container called `aap`, running an image that does not exist.

Strategic merge looked for a container with `name: aap`, found none, and concluded you must be adding one. That is the documented behaviour — a patch element whose merge key matches nothing is an **addition**, not an error.

Apply it and watch the consequence:

```plain
kubectl apply -k /root/app/overlay
sleep 20
kubectl get pods -l app=web
```{{exec}}

```plain
kubectl get pod -l app=web -o jsonpath='{.items[0].status.containerStatuses[*].name}{"\n"}'
kubectl describe pod -l app=web | grep -A3 "aap" | grep -iE "image|pull|error" | head -5
```{{exec}}

The Pod never becomes Ready. One container can't pull its image, so the whole Pod is held back — and the change you actually wanted (a new image on `app`) was never applied at all.

Clean up before the next step:

```plain
rm /root/app/overlay/typo-patch.yaml
cat > /root/app/overlay/kustomization.yaml <<'YAML'
resources:
  - ../base
patches:
  - path: env-patch.yaml
YAML
kubectl delete -k /root/app/overlay --ignore-not-found
```{{exec}}
