
Explore what this scenario gives you, then record the chart's template list into `/root/templates`.

<br>

<details><summary>Check the namespaces</summary>

```plain
kubectl get ns
```{{exec}}

Two namespaces matter here: `dev-ns` and `prod-ns`.

</details>

<details><summary>Check the chart templates</summary>

```plain
ls /charts/mock-app/templates
```{{exec}}

The chart renders a Deployment, a ConfigMap, a Service and an HPA (Horizontal Pod Autoscaler). The HPA is the one this scenario focuses on.

</details>

<details><summary>Check what renders today</summary>

```plain
helm template mock-app /charts/mock-app | grep '^kind:'
```{{exec}}

All four resources render, regardless of environment.

</details>

<details><summary>Solution</summary>

```plain
ls /charts/mock-app/templates > /root/templates
cat /root/templates
```{{exec}}

</details>
