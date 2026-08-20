
A ReplicaSet named `whoami-web` exists directly — no owning Deployment. Scale it to 3 replicas by editing the ReplicaSet itself. Confirm the resulting Pods are owned by the ReplicaSet directly, with no Deployment anywhere in the chain.

<br>

<details><summary>Tip</summary>

```
kubectl get rs whoami-web
kubectl get pod -l app=whoami-web -o custom-columns=NAME:.metadata.name,OWNER:.metadata.ownerReferences[0].kind
```{{exec}}

`kubectl scale rs whoami-web --replicas=3` is the fastest way; editing the YAML's `replicas` field works too.

</details>

<details><summary>Solution</summary>

```
kubectl scale rs whoami-web --replicas=3
```{{exec}}

```
kubectl get rs whoami-web
kubectl get pod -l app=whoami-web -o custom-columns=NAME:.metadata.name,OWNER:.metadata.ownerReferences[0].kind
```{{exec}}

</details>
