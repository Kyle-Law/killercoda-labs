
<br>

`namePrefix` looks like the safest thing in Kustomize. You add one line, every object gets a prefix, and nothing about your application changes.

Except Kustomize only rewrites the references it **understands structurally** — a `configMapRef.name`, a Service selector, an owner reference. A hostname sitting inside a ConfigMap value, or inside a container argument, is just a string. Kustomize has no idea it's an address, so it leaves it alone.

The result is the worst kind of failure: `kubectl apply` succeeds, every object is created, nothing reports an error — and the app can't reach its backend, because the Service moved and the config didn't follow.

You'll cause that failure, watch the obvious fix (`vars`) silently do nothing, and then fix it properly with `replacements`.

> A base is ready at `/root/app/base` — a `backend` Service and a `frontend` that reads `BACKEND_HOST` from a ConfigMap and curls it in a loop, so a broken reference is visible in the logs.
