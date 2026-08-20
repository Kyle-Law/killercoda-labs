
<br>

### Recap

- Containers in a Pod share network (`localhost`) and can share volumes — but each mount gets its own access level, so one container can write while another can only read.
- Init containers run in sequence, and every one must finish before any app container starts. It's the standard way to guarantee an environment is ready before your app touches it.
- The **sidecar pattern**: a helper container extends the app container without changing its image or code — here, adapting file-based logs to the stdout stream Kubernetes actually watches.

### WELL DONE!

A Pod isn't a lightweight VM — it's one component with helpers, not a bundle of unrelated services. These three patterns are how you keep it that way while still solving real integration problems.
