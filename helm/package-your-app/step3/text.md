
The page still says "Hello from somewhere". Make it say which environment it's running in.

Change `files/index.html` so the heading reads **`Hello from dev`** when `environment` is `dev`, driven by the `environment` value — without hardcoding `dev` anywhere in the HTML.

Then upgrade the `dev` release and confirm `curl localhost:30080` shows the new text.

<br>

<details><summary>Tip</summary>

`.Files.Get` returns the file's contents as a **plain string** — any `{{ ... }}` inside it is returned literally, not evaluated.

To render that string as a template, wrap it in [`tpl`](https://helm.sh/docs/howto/charts_tips_and_tricks/#using-the-tpl-function), which takes a string and a context:

```plain
{{ tpl (.Files.Get "files/index.html") . }}
```

</details>

<details><summary>Solution</summary>

Put the value reference into the HTML itself:

```plain
cat > /root/charts/site/files/index.html <<'HTML'
<!doctype html>
<html>
  <head><title>My Site</title></head>
  <body>
    <h1>Hello from {{ .Values.environment }}</h1>
    <p>Served by nginx on Kubernetes.</p>
  </body>
</html>
HTML
```{{exec}}

Then render it through `tpl` instead of inserting it raw:

```plain
cat > /root/charts/site/templates/configmap.yaml <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-site
data:
  index.html: |
{{ tpl (.Files.Get "files/index.html") . | indent 4 }}
YAML
```{{exec}}

Check the substitution happened before deploying:

```plain
helm template dev /root/charts/site | grep "Hello from"
```{{exec}}

```plain
helm upgrade dev /root/charts/site --wait
curl localhost:30080
```{{exec}}

</details>

<br>

> If the page doesn't change, look at whether the Pod restarted. This is exactly what the `checksum/config` annotation is for.
