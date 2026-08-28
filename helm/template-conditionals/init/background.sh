#!/bin/bash

# Build the mock-app chart locally. The upstream scenarios pulled this from a
# personal Docker Hub OCI artifact and a personal git repo; generating it here
# removes both external dependencies.
mkdir -p /charts/mock-app/templates

cat > /charts/mock-app/Chart.yaml <<'EOF'
apiVersion: v2
name: mock-app
description: A mock application for learning Helm
type: application
version: 1.0.0
appVersion: "1.0.0"
EOF

cat > /charts/mock-app/values.yaml <<'EOF'
appName: mock-app
message: You will override this message
image:
  repository: busybox
  tag: "1.36"
EOF

cat > /charts/mock-app/templates/configmap.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Values.appName }}-configmap
  labels:
    app: {{ .Values.appName }}
data:
  MESSAGE: {{ .Values.message | quote }}
EOF

cat > /charts/mock-app/templates/deployment.yaml <<'EOF'
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
EOF

cat > /charts/mock-app/templates/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.appName }}-service
  labels:
    app: {{ .Values.appName }}
spec:
  selector:
    app: {{ .Values.appName }}
  ports:
    - port: 5000
      targetPort: 5000
EOF

# this scenario's chart also ships an HPA, and adds an 'environment' value
cat >> /charts/mock-app/values.yaml <<'VEOF'
environment: dev
VEOF

cat > /charts/mock-app/templates/hpa.yaml <<'HEOF'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ .Values.appName }}-hpa
  labels:
    app: {{ .Values.appName }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ .Values.appName }}-deployment
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 80
HEOF

kubectl create ns dev-ns
kubectl create ns prod-ns

touch /tmp/.initfinished
