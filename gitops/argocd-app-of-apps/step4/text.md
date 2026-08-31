
`argocd-example-apps` has a `lightweight/` folder with two subdirectories, `app-a` and `app-b`, each just a single ConfigMap tagged with its own name — built for exactly this kind of demo.

Write an `ApplicationSet` named `lightweight-apps` with a **git directory** generator matching `lightweight/*`, templating one Application per matched directory: name `lightweight-{{path.basename}}`, source path `{{path}}`, destination namespace `lightweight-{{path.basename}}` (`CreateNamespace=true`), automated with prune and self-heal. Confirm both `app-a` and `app-b` show up automatically — you never told it there were two, it found them.

Now narrow the pattern to just `lightweight/app-a` and re-apply. Nothing about `app-b`'s Application was deleted by you — predict what happens to it anyway.

<br>

<details><summary>Tip</summary>

```
kubectl explain applicationset.spec.generators.git
```{{exec}}

Compare this to `guestbook-envs` from last step: that generator's element list only ever changes when you edit it. This one's "list" is really a live query against the repository — narrowing the path pattern changes what that query returns, on every reconcile, without you touching the set of Applications directly at all.

</details>

<details><summary>Solution</summary>

```
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: lightweight-apps
  namespace: argocd
spec:
  generators:
  - git:
      repoURL: https://github.com/argoproj/argocd-example-apps.git
      revision: HEAD
      directories:
      - path: lightweight/*
  template:
    metadata:
      name: 'lightweight-{{path.basename}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps.git
        targetRevision: HEAD
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: 'lightweight-{{path.basename}}'
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

`lightweight-app-a` and `lightweight-app-b`, discovered from the repo's actual structure, not from anything you enumerated.

```
kubectl patch applicationset lightweight-apps -n argocd --type merge -p '{"spec":{"generators":[{"git":{"repoURL":"https://github.com/argoproj/argocd-example-apps.git","revision":"HEAD","directories":[{"path":"lightweight/app-a"}]}}]}}'
```{{exec}}

```
argocd app list
```{{exec}}

`lightweight-app-b` is gone — pruned automatically, because it no longer matches what the generator currently returns. No `--prune` flag, no manual sync, nothing pointed at that specific Application at all: the `ApplicationSet` controller reconciles its whole managed set continuously, and an entry falling out of the generator's results is treated exactly like an entry being deleted from a list generator's `elements`.

</details>
