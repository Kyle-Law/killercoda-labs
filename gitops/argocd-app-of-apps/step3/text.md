
Write an `ApplicationSet` named `guestbook-envs` with a **list** generator producing three elements — `env: dev`, `env: staging`, `env: prod` — templating one Application per element: name `guestbook-{{env}}`, source the `guestbook` path from `argocd-example-apps`, destination namespace `guestbook-{{env}}` (with `CreateNamespace=true`), automated sync with self-heal.

Apply it and confirm all three Applications appear and sync on their own — an `ApplicationSet` isn't itself something you `argocd app sync`; it's a factory that manages `Application` objects for you.

<br>

<details><summary>Tip</summary>

```
kubectl explain applicationset.spec.generators.list
```{{exec}}

Template fields use the same `{{ }}` interpolation syntax as the App-of-Apps chart did, just driven by the generator's elements instead of a Helm values list.

</details>

<details><summary>Solution</summary>

```
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: guestbook-envs
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - env: dev
      - env: staging
      - env: prod
  template:
    metadata:
      name: 'guestbook-{{env}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps.git
        targetRevision: HEAD
        path: guestbook
      destination:
        server: https://kubernetes.default.svc
        namespace: 'guestbook-{{env}}'
      syncPolicy:
        syncOptions:
        - CreateNamespace=true
        automated:
          prune: true
          selfHeal: true
EOF
```{{exec}}

```
argocd app list
```{{exec}}

`guestbook-dev`, `guestbook-staging`, `guestbook-prod` — three Applications, all `Synced`/`Healthy`, none of them synced by hand. The `ApplicationSet` object itself doesn't run a sync; it just keeps the set of Applications matching its generator, and each generated Application's own `syncPolicy` does the rest.

</details>
