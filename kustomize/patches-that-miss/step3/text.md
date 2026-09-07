
Containers merge by `name` and env vars merge by `name`. But not every list has a key.

The `logger` sidecar runs:

```yaml
command: ["sh", "-c", "while true; do echo tick; sleep 30; done"]
```

Patch that container so its command echoes `tock` instead of `tick` — and see what happens to the rest of the list.

<br>

<details><summary>Tip</summary>

`command` and `args` are lists of plain strings. There is no field on a string that could act as a merge key.

</details>

<details><summary>Solution</summary>

```plain
cat > /root/app/overlay/cmd-patch.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  template:
    spec:
      containers:
        - name: logger
          command:
            - sh
            - -c
            - while true; do echo tock; sleep 30; done
YAML
```{{exec}}

```plain
cat > /root/app/overlay/kustomization.yaml <<'YAML'
resources:
  - ../base
patches:
  - path: env-patch.yaml
  - path: cmd-patch.yaml
YAML
```{{exec}}

```plain
kubectl kustomize /root/app/overlay | sed -n '/name: logger/,$p'
kubectl kustomize /root/app/overlay | grep -B6 "name: logger"
```{{exec}}

</details>

<br>

## Replaced, not merged

The whole `command` list was swapped for yours. That's why the patch had to repeat `sh` and `-c` — omit them and the container's entrypoint becomes just the loop string, which is not executable on its own.

This is the rule underneath both steps:

| List | Merge key | Patch behaviour |
|---|---|---|
| `containers` | `name` | merged per element; unmatched key **adds** |
| `env`, `ports`, `volumeMounts` | `name` / `containerPort` | merged per element |
| `command`, `args` | none | **entire list replaced** |

Neither behaviour is wrong, but they are opposite, and nothing in the patch file tells you which one you're getting. You have to know the merge key — or use a patch type that doesn't rely on one.
