
Strategic merge guesses. JSON 6902 doesn't.

A JSON patch is a list of explicit operations against explicit paths — `add`, `remove`, `replace`. There is no merge key and no inference: the path either exists or the build fails.

Use it for something strategic merge cannot express — **removing** an env var — plus a simple scalar change.

**1.** Remove `KEEP_ME` from the `app` container and set `replicas` to `3`.
**2.** Then discover what index-based paths cost you.

<br>

<details><summary>Tip: find the indices first</summary>

JSON paths address list elements **by position**, so check the current order before writing them:

```plain
kubectl kustomize /root/app/overlay | grep -nE "^        name: |^        - name: "
```{{exec}}

Note which container is first — it may not be the one you expect.

</details>

<details><summary>Solution</summary>

After step 3, `logger` is container `0` and `app` is container `1`, whose env is `LOG_LEVEL` then `KEEP_ME`:

```plain
cat > /root/app/overlay/kustomization.yaml <<'YAML'
resources:
  - ../base
patches:
  - path: env-patch.yaml
  - path: cmd-patch.yaml
  - target:
      kind: Deployment
      name: web
    patch: |-
      - op: remove
        path: /spec/template/spec/containers/1/env/1
      - op: replace
        path: /spec/replicas
        value: 3
YAML
```{{exec}}

```plain
kubectl kustomize /root/app/overlay | grep -E "replicas:|name: (KEEP_ME|LOG_LEVEL)$"
```{{exec}}

`KEEP_ME` is gone, `LOG_LEVEL` remains, replicas is 3.

</details>

<br>

## Now break it without touching it

The JSON patch above is correct. Remove the *unrelated* `logger` patch from step 3 and rebuild — changing nothing about the JSON patch itself:

```plain
cp /root/app/overlay/kustomization.yaml /tmp/k-good.yaml
cat > /root/app/overlay/kustomization.yaml <<'YAML'
resources:
  - ../base
patches:
  - path: env-patch.yaml
  - target:
      kind: Deployment
      name: web
    patch: |-
      - op: remove
        path: /spec/template/spec/containers/1/env/1
      - op: replace
        path: /spec/replicas
        value: 3
YAML
kubectl kustomize /root/app/overlay; echo "exit=$?"
```{{exec}}

<details><summary>Why that failed</summary>

Patching the `logger` container in step 3 moved it to the **front** of the list. Strategic merge does not preserve the original ordering of elements it touches.

So with the logger patch present, `containers/1` is `app`. Without it, `containers/1` is `logger` — which has no `env` at all, and the build dies:

```plain
error: remove operation does not apply: doc is missing path
```

Your JSON patch was never edited. An unrelated patch, elsewhere in the file, silently changed what its paths pointed at.

</details>

Restore the working version:

```plain
cp /tmp/k-good.yaml /root/app/overlay/kustomization.yaml
kubectl kustomize /root/app/overlay >/dev/null && echo "restored OK"
```{{exec}}

<br>

## The trade

| | Strategic merge | JSON 6902 |
|---|---|---|
| Targets list items by | merge key (`name`) | **index** |
| Key/path doesn't match | silently **adds** an element | **build fails** |
| Survives list reordering | yes | **no** — as you just saw |
| Can remove a list element | only via `$patch: delete` | yes, natively |
| Readability | looks like the resource | looks like operations |

Neither is a safe default. Strategic merge is order-independent and readable, but fails silently. JSON 6902 always fails loudly — and its paths are positional, so an unrelated patch can invalidate them.

Reach for JSON 6902 when you need an operation strategic merge can't express, and prefer scalar paths like `/spec/replicas` over indexed ones wherever you have the choice.
