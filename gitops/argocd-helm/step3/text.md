
`podinfo-helm` is a chart-repository source — there's no Git repo backing it, so there's nowhere to commit a values file the way `packaging/helm-values-precedence` did with `-f`. You still want to hand it a whole block of values at once, not a pile of individual `--helm-set` flags.

Write `/root/podinfo-values.yaml` with `replicaCount: 3` and `ui.message: "from argocd inline values"`, and get it applied — without it ever needing to exist in a Git repo. Then look at where that content actually ended up on the Application object.

<br>

<details><summary>Tip</summary>

```
argocd app set --help | grep -A2 'values-literal-file\|^\s*--values\b'
```{{exec}}

Two similarly-named flags: `--values` expects a path *inside the source* (a file the repo-server would have to fetch from Git — no use here). `--values-literal-file` reads from your **local** filesystem and embeds the content directly.

</details>

<details><summary>Solution</summary>

```
cat > /root/podinfo-values.yaml <<'EOF'
replicaCount: 3
ui:
  message: "from argocd inline values"
EOF
```{{exec}}

```
argocd app set podinfo-helm --values-literal-file /root/podinfo-values.yaml
argocd app sync podinfo-helm
```{{exec}}

```
kubectl get application podinfo-helm -n argocd -o yaml | grep -A5 valuesObject
```{{exec}}

The whole block is sitting right there in the Application's own spec, under `helm.valuesObject` — not a reference to your file, the actual content. From here it behaves like any other part of the desired state: it's what the next sync compares against, with or without `/root/podinfo-values.yaml` still existing on disk.

</details>
