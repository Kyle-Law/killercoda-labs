
<br>

### Recap

- **`namePrefix` rewrites references Kustomize understands structurally** — `configMapRef.name`, `serviceAccountName`, Ingress backend service names, and the rest of its built-in name-reference list. Everything else is an opaque string it will never touch.
- **That failure is silent.** The manifests are valid, the objects are created, the Deployment goes Available. Only the application knows, and only at runtime.
- **`vars` is deprecated, and it fails without erroring** — it leaves `$(NAME)` in place and emits a warning to *stderr*, where a piped `apply` or a GitOps sync will never show it to you.
- **`replacements` states the dependency explicitly**: this field, from this object, into those fields. It runs after prefixing, so it reads the final name — and it fails loudly when a path doesn't match.
- **`options.delimiter` / `index`** rewrite one segment of a longer string, for addresses embedded in flags and connection strings.

### The habit

After adding any `namePrefix` or `nameSuffix`, grep the rendered output for the old name:

```plain
kubectl kustomize ./overlay | grep -n "oldname" | grep -v "prefix-oldname"
```

Anything that comes back is a reference the rename left behind — and nothing else is going to tell you.

### WELL DONE!
