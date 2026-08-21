
`db` is back to a clean 2-replica StatefulSet, this time with a `volumeClaimTemplates` entry giving each replica its own 10Mi volume at `/data`.

Write `important-data` into `/data/marker.txt` on `db-1`. Scale `db` down to 1 replica — confirm `db-1` is gone, but its PVC (`data-db-1`) still exists. Scale back up to 2 — confirm the new `db-1` reattaches to that same PVC, and your data is still there.

<br>

<details><summary>Tip</summary>

```
kubectl get pvc
kubectl scale statefulset db --replicas=1
kubectl get pvc
```{{exec}}

A PVC from `volumeClaimTemplates` is tied to the ordinal, not to any specific Pod object — scaling down removes the Pod, not the claim.

</details>

<details><summary>Solution</summary>

```
kubectl exec db-1 -- sh -c "echo important-data > /data/marker.txt"
```{{exec}}

```
kubectl scale statefulset db --replicas=1
kubectl get pvc data-db-1
```{{exec}}

The PVC is still there even with `db-1` gone.

```
kubectl scale statefulset db --replicas=2
kubectl wait --for=condition=Ready pod/db-1 --timeout=60s
kubectl exec db-1 -- cat /data/marker.txt
```{{exec}}

</details>
