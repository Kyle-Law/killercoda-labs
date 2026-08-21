
StatefulSet `db` wants 3 replicas, but only `db-0` exists — and it's stuck `0/1 Ready`. `db-1` and `db-2` haven't even been created yet.

Work out why, then fix it: make `db-0` pass its readiness probe. Watch what happens next — you'll need to repeat the fix for each ordinal as it appears, one at a time, until all 3 are `Ready`.

<br>

<details><summary>Tip</summary>

```
kubectl describe pod db-0 | grep -A5 Readiness
kubectl get pod -l app=db
```{{exec}}

A StatefulSet's default `OrderedReady` policy means the *next* ordinal isn't even created until the current one is fully `Ready` — not just `Running`.

</details>

<details><summary>Solution</summary>

```
kubectl exec db-0 -- touch /tmp/ready
```{{exec}}

Wait a few seconds and check again — `db-1` should now exist, also stuck `0/1 Ready` with the same probe. Repeat:

```
kubectl exec db-1 -- touch /tmp/ready
```{{exec}}

Then once `db-2` appears:

```
kubectl exec db-2 -- touch /tmp/ready
```{{exec}}

```
kubectl get statefulset db
```{{exec}}

</details>
