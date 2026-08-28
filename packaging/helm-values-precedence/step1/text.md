
Dump the chart's full defaults to `/root/podinfo-defaults.yaml` for reference (`helm show values ... > file`), and find the two fields that control replica count and the UI message.

Now author a **separate**, minimal file, `/root/values1.yaml`, containing only those two overrides: `replicaCount: 2`, and `ui.message` set to exactly `hello from values1`. Upgrade `podinfo-values1` with `-f /root/values1.yaml`.

Confirm `helm get values podinfo-values1` shows **exactly** those two keys — not the dozens of other fields in the defaults dump — and that the Deployment is actually running 2 replicas.

<br>

<details><summary>Tip</summary>

```
helm show values podinfo/podinfo --version 6.5.4 | head -20
```{{exec}}

`-f` doesn't need every field the chart supports — only the ones you're changing. Everything you leave out keeps the chart's own default.

</details>

<details><summary>Solution</summary>

```
helm show values podinfo/podinfo --version 6.5.4 > /root/podinfo-defaults.yaml
```{{exec}}

```
cat > /root/values1.yaml <<'EOF'
replicaCount: 2
ui:
  message: "hello from values1"
EOF
```{{exec}}

```
helm upgrade podinfo-values1 podinfo/podinfo --version 6.5.4 -f /root/values1.yaml
```{{exec}}

```
helm get values podinfo-values1
kubectl get deployment podinfo-values1
```{{exec}}

Two keys, not the full tree — `helm get values` only ever shows what *you* supplied, never the chart's own defaults, unless you ask for those separately (next step).

</details>
