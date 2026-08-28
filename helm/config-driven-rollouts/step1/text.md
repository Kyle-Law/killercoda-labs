
A mock application is deployed with Helm in `dev-ns`. Explore it, then save what the app currently serves into `/root/before`.

<br>

<details><summary>Check the release and resources</summary>

```plain
helm list -n dev-ns
kubectl get all -n dev-ns
```{{exec}}

</details>

<details><summary>Check what the container serves</summary>

```plain
export SERVICE_IP=$(kubectl get svc -n dev-ns mock-app-service -o jsonpath='{.spec.clusterIP}')
curl -s http://${SERVICE_IP}:5000
echo
```{{exec}}

</details>

<details><summary>Check the ConfigMap behind it</summary>

```plain
kubectl get cm -n dev-ns mock-app-configmap -o jsonpath='{.data}'
echo
```{{exec}}

`MESSAGE` is the key the container reads.

</details>

<details><summary>Check the templates</summary>

```plain
cat /charts/mock-app/templates/configmap.yaml
cat /charts/mock-app/templates/deployment.yaml
```{{exec}}

The Deployment pulls the ConfigMap in with `envFrom`, and the container writes that value into its page **at startup**.

</details>

<details><summary>Solution</summary>

```plain
export SERVICE_IP=$(kubectl get svc -n dev-ns mock-app-service -o jsonpath='{.spec.clusterIP}')
curl -s http://${SERVICE_IP}:5000 > /root/before
cat /root/before
```{{exec}}

</details>
