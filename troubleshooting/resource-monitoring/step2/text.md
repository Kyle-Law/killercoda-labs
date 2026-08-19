
A Deployment named `web` in the `quota-ns` namespace has `0/3` Pods running. Find out why, then fix it so all 3 replicas run — by adjusting either the Deployment's resource requests or the namespace's `ResourceQuota`.

<br>

<details><summary>Tip</summary>

```
kubectl get pods -n quota-ns
kubectl get resourcequota -n quota-ns
kubectl describe resourcequota compute-quota -n quota-ns
kubectl get replicaset -n quota-ns
kubectl describe replicaset -n quota-ns
```{{exec}}

Check the ReplicaSet's `Events` for why it can't create Pods.

</details>

<details><summary>Solution</summary>

A `ResourceQuota` is fully mutable:

```
kubectl patch resourcequota compute-quota -n quota-ns --type merge -p '{"spec":{"hard":{"requests.cpu":"1","requests.memory":"1Gi"}}}'
```{{exec}}

```
kubectl get pods -n quota-ns
```{{exec}}

</details>
