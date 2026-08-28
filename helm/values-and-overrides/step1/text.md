
A mock application is deployed with Helm in the `dev-ns` namespace. Explore what's there, then record the message the app is currently serving into `/root/message`.

<br>

<details><summary>Check the release</summary>

```plain
helm list -n dev-ns
```{{exec}}

</details>

<details><summary>Check the deployed resources</summary>

```plain
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

<details><summary>Check where that message comes from</summary>

```plain
helm get values --all mock-app -n dev-ns
```{{exec}}

The message comes from the chart's default values — `message: You will override this message`. The chart itself lives in `/charts/mock-app`.

</details>

<details><summary>Solution</summary>

```plain
export SERVICE_IP=$(kubectl get svc -n dev-ns mock-app-service -o jsonpath='{.spec.clusterIP}')
curl -s http://${SERVICE_IP}:5000 > /root/message
cat /root/message
```{{exec}}

</details>
