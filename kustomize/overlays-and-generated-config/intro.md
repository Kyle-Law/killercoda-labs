
<br>

Kustomize has no templates, no values files, no placeholders and no release state. It reads plain, valid Kubernetes YAML and returns different plain, valid Kubernetes YAML. That's the whole tool — and it's already inside `kubectl`, as `kubectl kustomize` and `kubectl apply -k`.

Two ideas carry most of the value:

- **bases and overlays** — one set of manifests, transformed per environment, with each environment recording only its differences rather than a full copy
- **generators** — `configMapGenerator` and `secretGenerator`, which build config objects with a **content hash in the name** and rewrite every reference to match

That second one is the part people switch off before they understand it. It exists to fix a bug you've probably shipped: change a ConfigMap in place and the Pods using it carry on with the old values indefinitely, because nothing about their Deployment changed. You'll cause that bug on purpose in step 4, and watch the hash prevent it.

`gitops/argocd-kustomize` covers what Argo CD does when it runs `kustomize build` for you, and the sharp edges of its CLI overrides. This lab is about the tool itself.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
