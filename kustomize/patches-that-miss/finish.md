
<br>

### Recap

- **Strategic merge finds list elements by merge key** — `name` for containers, env vars and volume mounts; `containerPort` for ports. Matched elements are merged field by field, so everything you didn't mention survives.
- **An unmatched key is an addition, not an error.** One transposed character turned an image bump into a third container running an image that doesn't exist. The build succeeded, the apply succeeded, and the Pod never started.
- **Lists without a key are replaced wholesale.** `command` and `args` are plain strings with nothing to merge on, which is why a patch must repeat the whole list including `sh -c`.
- **JSON 6902 addresses by path and index, and fails loudly.** No merge key, no inference — a wrong path stops the build instead of producing something plausible.
- **`kubectl patch --type merge` is a third thing again**: a JSON merge patch, which replaces lists unconditionally. The same patch text behaves differently depending on which tool applies it.

### The habit

After any patch, diff the render rather than trusting it:

```plain
kubectl kustomize ./base > /tmp/before.yaml
kubectl kustomize ./overlay > /tmp/after.yaml
diff /tmp/before.yaml /tmp/after.yaml
```

A patch that silently missed shows up immediately as an added block rather than a changed line.

### WELL DONE!
