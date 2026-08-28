
Restarting by hand works, but it's a step someone has to remember every single time. Charts solve this properly with a **checksum annotation**.

The idea: render the ConfigMap, hash it, and put that hash into the Deployment's **Pod template** as an annotation. When the ConfigMap's content changes, the hash changes, so the Pod template changes — and Kubernetes rolls the Deployment automatically, because that's what it always does when a Pod template changes.

[Helm documentation](https://helm.sh/docs/howto/charts_tips_and_tricks/#automatically-roll-deployments)

Edit `/charts/mock-app/templates/deployment.yaml` and add the annotation block under `spec.template.metadata`.

<br>

<details><summary>The annotation to add</summary>

```yaml
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
      labels:
        app: {{ .Values.appName }}
```

`$.Template.BasePath` resolves to the chart's `templates` directory, so this renders the ConfigMap template and hashes the result.

</details>

<details><summary>Solution</summary>

```plain
cat > /charts/mock-app/templates/deployment.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.appName }}-deployment
  labels:
    app: {{ .Values.appName }}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {{ .Values.appName }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
      labels:
        app: {{ .Values.appName }}
    spec:
      containers:
        - name: {{ .Values.appName }}-container
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          command:
            - sh
            - -c
            - mkdir -p /www && printf '%s' "Hello Killercoda Folks! You received this message: $MESSAGE" > /www/index.html && httpd -f -p 5000 -h /www
          ports:
            - containerPort: 5000
          envFrom:
            - configMapRef:
                name: {{ .Values.appName }}-configmap
YAML
```{{exec}}

Check that it renders before using it:

```plain
helm template mock-app /charts/mock-app | grep -A2 annotations
```{{exec}}

</details>

<br>

There's no verification on this step — the next one proves whether it worked.
