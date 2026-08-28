
Three small tasks against `podinfo-values4`, each demonstrating a `--set` variant that exists because plain `--set` has a sharp edge. Do them **in order**, each building on the last (you'll need `--reuse-values` from the second one onward).

**1. `--set-file`.** `/root/release-notes.txt` holds a short message. Upgrade, loading that file's *exact contents* into `ui.message` — without retyping it — using the flag built for exactly this (the same trick used to load a certificate or a script body from disk). Confirm the Pod's env carries the file's contents.

**2. `--set-string`.** Upgrade again, adding `--set podAnnotations.build=42` — a bare number. Check `helm get values`: Helm stored `42` as a genuine YAML integer, not the string `"42"`. Redo it with `--set-string podAnnotations.build=42` instead, and confirm `helm get values` now shows it quoted. (This chart happens to defensively quote every annotation it renders, so nothing breaks either way here — but plenty of charts don't, and an unquoted number landing in a string-typed Kubernetes field is a real `helm upgrade` failure: *cannot unmarshal number into Go string*.)

**3. List index.** Turn the Ingress on and set its first host to `api.example.com`, using index syntax rather than a values file. Confirm with `kubectl get ingress`.

Try it with just the host field first — it will fail. `helm upgrade --set` merges maps deeply, but it replaces lists **wholesale**: touching `ingress.hosts[0]` at all discards the chart's entire default entry, `paths` included, not just the field you named. The Ingress schema requires `paths`, so you'll need to supply that too, even though you don't care what it is.

<br>

<details><summary>Tip</summary>

```
helm upgrade --help | grep -A2 'set-file\|set-string'
```{{exec}}

Quote index-style `--set` flags — `--set 'list[0].key=val'` — most shells treat an unquoted `[` as a glob pattern and will refuse to expand it.

</details>

<details><summary>Solution</summary>

```
helm upgrade podinfo-values4 podinfo/podinfo --version 6.5.4 --set-file ui.message=/root/release-notes.txt
```{{exec}}

```
kubectl get pods -l app.kubernetes.io/name=podinfo-values4 -o jsonpath='{.items[0].spec.containers[0].env}'
```{{exec}}

```
helm upgrade podinfo-values4 podinfo/podinfo --version 6.5.4 --reuse-values --set podAnnotations.build=42
helm get values podinfo-values4
```{{exec}}

`build: 42` — unquoted, a number.

```
helm upgrade podinfo-values4 podinfo/podinfo --version 6.5.4 --reuse-values --set-string podAnnotations.build=42
helm get values podinfo-values4
```{{exec}}

`build: "42"` — quoted, a string. Same input, different stored type — that's the entire difference `--set-string` makes.

```
helm upgrade podinfo-values4 podinfo/podinfo --version 6.5.4 --reuse-values --set ingress.enabled=true --set 'ingress.hosts[0].host=api.example.com'
```{{exec}}

That fails: `spec.rules[0].http.paths: Required value` — the default `paths` entry got wiped the moment `hosts[0]` was touched at all.

```
helm upgrade podinfo-values4 podinfo/podinfo --version 6.5.4 --reuse-values \
  --set ingress.enabled=true \
  --set 'ingress.hosts[0].host=api.example.com' \
  --set 'ingress.hosts[0].paths[0].path=/' \
  --set 'ingress.hosts[0].paths[0].pathType=ImplementationSpecific'
kubectl get ingress
```{{exec}}

</details>
