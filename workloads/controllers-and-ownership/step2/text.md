
Deployment `pi-web` runs 2 replicas of `nginx:stable-alpine`. Work through this in order:

1. Before touching anything, find its current ReplicaSet's name and write it into `/root/original-rs.txt`.
2. Scale `pi-web` to 3 replicas. Confirm the **same** ReplicaSet you just recorded grew to 3 — not a new one.
3. Now change the container image to `nginx:1.27-alpine`. Confirm a **brand-new** ReplicaSet appears with all 3 replicas ready, and the original ReplicaSet from step 1 is still there, just scaled down to 0 — not deleted.

<br>

<details><summary>Tip</summary>

```
kubectl get rs -l app=pi-web
```{{exec}}

A `replicas` change and a Pod-template change (image, env, anything under `template:`) affect ReplicaSets very differently — that's the whole point of this exercise.

</details>

<details><summary>Solution</summary>

```
kubectl get rs -l app=pi-web -o jsonpath='{.items[0].metadata.name}' > /root/original-rs.txt
cat /root/original-rs.txt
```{{exec}}

```
kubectl scale deployment pi-web --replicas=3
kubectl get rs -l app=pi-web
```{{exec}}

The name in `/root/original-rs.txt` should now show 3/3 — same ReplicaSet, just scaled.

```
kubectl set image deployment/pi-web nginx=nginx:1.27-alpine
kubectl rollout status deployment/pi-web
kubectl get rs -l app=pi-web
```{{exec}}

Now there are two ReplicaSets: the original one (from the file) at 0, and a new one at 3.

</details>
