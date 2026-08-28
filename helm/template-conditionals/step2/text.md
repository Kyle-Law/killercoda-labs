
Add a condition to the HPA template so that:

- releases in the **prod** environment get an HPA
- releases in any other environment do **not**

Then prove it by deploying two releases from the same chart:

- `mock-app-prod` in namespace `prod-ns`, with `environment=prod`
- `mock-app-dev` in namespace `dev-ns`, with `environment=dev`

> The chart is at `/charts/mock-app`, and it already has an `environment` value.

<br>

<details><summary>Tip</summary>

Guard the template with `{{- if ... }}` and close it with `{{- end }}`. Because a half-rendered manifest wouldn't be valid YAML, the guard has to wrap the **entire** file, not just part of it.

Check your work without installing anything:

```plain
helm template x /charts/mock-app --set environment=dev | grep -c HorizontalPodAutoscaler
helm template x /charts/mock-app --set environment=prod | grep -c HorizontalPodAutoscaler
```{{exec}}

</details>

<details><summary>Solution</summary>

Wrap `/charts/mock-app/templates/hpa.yaml` in the condition:

```plain
cat > /charts/mock-app/templates/hpa.yaml <<'YAML'
{{- if eq .Values.environment "prod" }}
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
{{- end }}
YAML
```{{exec}}

Verify the rendering before deploying:

```plain
helm template x /charts/mock-app --set environment=dev | grep -c HorizontalPodAutoscaler
helm template x /charts/mock-app --set environment=prod | grep -c HorizontalPodAutoscaler
```{{exec}}

Then deploy both:

```plain
helm -n prod-ns upgrade --install mock-app-prod /charts/mock-app --set environment=prod
```{{exec}}

```plain
helm -n dev-ns upgrade --install mock-app-dev /charts/mock-app --set environment=dev
```{{exec}}

```plain
kubectl get hpa -A
```{{exec}}

</details>
