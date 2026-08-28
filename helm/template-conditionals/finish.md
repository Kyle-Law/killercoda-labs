
<br>

### Recap

- `{{- if ... }}` / `{{- end }}` around a whole template file makes that resource render only when the condition holds — the standard way to make one chart serve several environments.
- Wrapping the *entire* file matters: a partially rendered manifest is invalid YAML, so the guard has to be the outermost thing in the file.
- `helm template --set environment=...` renders locally without touching the cluster, which is the fastest way to check a condition before installing anything.

### WELL DONE!
