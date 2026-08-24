
The operator bundle has been applied. Before using it, confirm what it actually gave you:

- the `prometheus-operator` Deployment is running
- new **CustomResourceDefinitions** exist in the `monitoring.coreos.com` API group — these are the new object types the operator understands

Count how many CRDs the bundle registered under `monitoring.coreos.com`, and write just that number into `/root/crd-count.txt`.

<br>

<details><summary>Tip</summary>

```
kubectl get deployment prometheus-operator
kubectl get crd | grep monitoring.coreos.com
```{{exec}}

```
kubectl api-resources --api-group=monitoring.coreos.com
```{{exec}}

An operator is just a Deployment — what makes it an *operator* is the CRDs it ships alongside, plus the controller logic watching for those custom resources.

</details>

<details><summary>Solution</summary>

```
kubectl get crd | grep -c monitoring.coreos.com
```{{exec}}

```
echo "<the-number-you-counted>" > /root/crd-count.txt
```{{exec}}

</details>
