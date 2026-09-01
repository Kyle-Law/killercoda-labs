#!/bin/bash

mkdir -p /root/solar-system-app
cat > /root/solar-system-app/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: solar-system
  labels:
    app: solar-system
spec:
  replicas: 2
  selector:
    matchLabels:
      app: solar-system
  template:
    metadata:
      labels:
        app: solar-system
    spec:
      containers:
      - name: solar-system
        image: handafew/solar-system:v3
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 10
EOF
cat > /root/solar-system-app/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: solar-system
  labels:
    app: solar-system
spec:
  type: NodePort
  selector:
    app: solar-system
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30090
EOF

touch /tmp/step2-applied
