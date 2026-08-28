
<br>

### Recap

- A static file becomes a Kubernetes app via a **ConfigMap** mounted into an `nginx` container — no image build required.
- `.Files.Get` reads a real file out of the chart, and `tpl` renders it as a template, so `index.html` stays an actual file that a designer can edit while still picking up `{{ .Values.environment }}`.
- A **NodePort** Service pins a fixed port on the node, which is what lets two releases of the same chart be reachable at the same time on different ports.
- One chart plus one values file per environment is the whole per-environment story: `-f values-prod.yaml` changed the page text, the replica count and the port without touching a single template.
- The `checksum/config` annotation is what makes an edit to `index.html` actually reach a running Pod — without it the ConfigMap updates but the Pod keeps serving the old page.

### WELL DONE!

That's the full path from a file on disk to a parameterised, multi-environment release.
