
In-cluster DNS lookups are failing — `test-client` (from the previous step) can't resolve service names anymore, even though Services and Endpoints are otherwise fine. Investigate the `coredns` Deployment in the `kube-system` namespace and fix it.

<br>

<details><summary>Tip</summary>

```
kubectl exec test-client -- nslookup kubernetes.default
```{{exec}}

```
kubectl -n kube-system get deployment coredns
kubectl -n kube-system get pods -l k8s-app=kube-dns
```{{exec}}

</details>

<details><summary>Solution</summary>

```
kubectl -n kube-system scale deployment coredns --replicas=2
```{{exec}}

```
kubectl exec test-client -- nslookup kubernetes.default
```{{exec}}

</details>
