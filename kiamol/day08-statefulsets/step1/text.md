
StatefulSet `web` runs Pods `web-0` and `web-1` — predictable names, unlike a ReplicaSet's random suffixes. Delete `web-0`. Confirm it comes back with the exact same name, `web-0`, but as a genuinely **new object** underneath (a different UID) — and that `web-1` was never touched.

<br>

<details><summary>Tip</summary>

```
kubectl get pod web-0 -o jsonpath='{.metadata.uid}'
```{{exec}}

A StatefulSet's Pods are created in order (0, then 1, ...), but replacing a missing one doesn't reorder anything else — only creation and scaling are ordered, not repair.

</details>

<details><summary>Solution</summary>

```
kubectl delete pod web-0
```{{exec}}

```
kubectl get pod web-0 web-1
kubectl get pod web-0 -o jsonpath='{.metadata.uid}'
```{{exec}}

Compare that UID against `/root/original-web0-uid.txt` — different UID, same name.

</details>
