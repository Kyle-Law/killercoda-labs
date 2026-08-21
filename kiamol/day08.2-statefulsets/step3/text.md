
`db` now runs 3 replicas. Set its `updateStrategy` to `RollingUpdate` with `partition: 2`. Then change the container image to `busybox:1.36`.

Confirm only `db-2` updates — `db-0` and `db-1` stay on the original `busybox` image, still `Ready`, completely untouched by the change.

<br>

<details><summary>Tip</summary>

```
kubectl explain statefulset.spec.updateStrategy.rollingUpdate.partition
```{{exec}}

Every ordinal **at or above** the partition number gets updated; everything below it is left alone — a built-in canary mechanism, no separate tooling required.

</details>

<details><summary>Solution</summary>

```
kubectl patch statefulset db --type merge -p '{"spec":{"updateStrategy":{"type":"RollingUpdate","rollingUpdate":{"partition":2}}}}'
kubectl set image statefulset/db db=busybox:1.36
```{{exec}}

```
kubectl get pod -l app=db -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,READY:.status.containerStatuses[0].ready
```{{exec}}

</details>
