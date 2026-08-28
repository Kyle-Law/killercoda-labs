
Roll the `webserver` release back to the healthy revision 2, so its Pods run again.

Then look at the history once more — notice that rolling back doesn't erase anything.

<br>

<details><summary>Tip</summary>

```plain
helm rollback -h
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
helm rollback webserver 2
```{{exec}}

```plain
helm history webserver
kubectl get pods
```{{exec}}

The rollback didn't remove revision 3 — it created a **new** revision 4 whose content is a copy of revision 2, described as `Rollback to 2`. Helm's history is append-only, exactly like a Deployment's ReplicaSet history.

</details>
