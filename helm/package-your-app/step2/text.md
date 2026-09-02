
Now package the same thing as a chart. Remove the hand-made resources first so they don't collide:

```plain
kubectl delete deployment site
kubectl delete service site
kubectl delete configmap site
```{{exec}}

Create a chart at `/root/charts/site` that produces the **same three resources**, and install it as a release named `dev`. Requirements:

- the chart keeps `index.html` as a real file at `files/index.html` inside the chart, read into the ConfigMap rather than pasted into a template
- `replicaCount` and `service.nodePort` come from values, defaulting to `1` and `30080`
- resources are named after the release, so a second release won't clash

<br>

<details><summary>Tip</summary>

```plain
helm create -h
```{{exec}}

`helm create` scaffolds a chart with a lot of machinery you don't need here — it can be quicker to write four small files yourself.

To pull a file's contents into a template, use `.Files.Get`. Anything under the chart directory is available to it.

</details>

<details><summary>Solution</summary>

```plain
mkdir -p /root/charts/site/templates /root/charts/site/files
cp /root/site/index.html /root/charts/site/files/index.html
```{{exec}}

```plain
cat > /root/charts/site/Chart.yaml <<'YAML'
apiVersion: v2
name: site
description: A static website
type: application
version: 0.1.0
appVersion: "1.0.0"
YAML
```{{exec}}

```plain
cat > /root/charts/site/values.yaml <<'YAML'
environment: dev
replicaCount: 1
image:
  repository: nginx
  tag: "1.27-alpine"
service:
  nodePort: 30080
YAML
```{{exec}}

```plain
cat > /root/charts/site/templates/configmap.yaml <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-site
data:
  index.html: |
{{ .Files.Get "files/index.html" | indent 4 }}
YAML
```{{exec}}

```plain
cat > /root/charts/site/templates/deployment.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-site
  labels:
    app: {{ .Release.Name }}-site
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Release.Name }}-site
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}-site
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
    spec:
      containers:
        - name: nginx
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          ports:
            - containerPort: 80
          volumeMounts:
            - name: site
              mountPath: /usr/share/nginx/html
      volumes:
        - name: site
          configMap:
            name: {{ .Release.Name }}-site
YAML
```{{exec}}

```plain
cat > /root/charts/site/templates/service.yaml <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-site
  labels:
    app: {{ .Release.Name }}-site
spec:
  type: NodePort
  selector:
    app: {{ .Release.Name }}-site
  ports:
    - port: 80
      targetPort: 80
      nodePort: {{ .Values.service.nodePort }}
YAML
```{{exec}}

Check it renders before installing anything:

```plain
helm lint /root/charts/site
helm template dev /root/charts/site
```{{exec}}

```plain
helm install dev /root/charts/site --wait
curl localhost:30080
```{{exec}}

</details>

<br>

> The `checksum/config` annotation in the Deployment isn't decoration — without it, editing `index.html` updates the ConfigMap but the running Pod keeps serving the old page. You'll rely on it in the next step.
