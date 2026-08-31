
`app-of-apps` is back to managing both children. Remove `kustomize-guestbook` from its `applications` list — write a new values block with just `guestbook` left in it — and sync with pruning enabled.

Before you check anything, predict three separate outcomes: does the `example.kustomize-guestbook` **Application object** disappear? Does the Deployment and Service *it* created disappear? Does the `kustomize-guestbook` **namespace** it was created in disappear? Then check all three.

<br>

<details><summary>Tip</summary>

`--values-literal-file` from `gitops/argocd-helm` fully replaces `valuesObject` — write the whole `applications` list fresh, with only the entry you want left in it. Pruning a child `Application` object doesn't automatically clean up what *that* Application created — whether it does depends on a finalizer. Check `kubectl get application example.kustomize-guestbook -o yaml` for one before you prune it, if you still can.

</details>

<details><summary>Solution</summary>

```
kubectl get application example.kustomize-guestbook -n argocd -o jsonpath='{.metadata.finalizers}'
```{{exec}}

`resources-finalizer.argocd.argoproj.io` — that's what's about to matter.

```
cat > /root/app-of-apps-values.yaml <<'EOF'
config:
  spec:
    destination:
      server: https://kubernetes.default.svc
    source:
      repoURL: https://github.com/argoproj/argocd-example-apps
      targetRevision: HEAD
applications:
- name: guestbook
  destination: {}
EOF
argocd app set app-of-apps --values-literal-file /root/app-of-apps-values.yaml
argocd app sync app-of-apps --prune
```{{exec}}

```
kubectl get application example.kustomize-guestbook -n argocd
kubectl -n kustomize-guestbook get deploy,svc
kubectl get ns kustomize-guestbook
```{{exec}}

The Application object: gone. Its Deployment and Service: gone too — the finalizer made sure of that before letting the Application object itself finish deleting. The namespace: still there. Argo CD created it on the way in; nothing un-creates it on the way out.

</details>
