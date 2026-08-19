
Find the name of the `StorageClass` that is configured as this cluster's **default** — the one dynamic-provisioning `PersistentVolumeClaims` will use automatically if you don't set `storageClassName` yourself.

Write just that name (nothing else) into `/root/default-sc.txt`.

<br>

<details><summary>Tip</summary>

```
kubectl get storageclass
```{{exec}}

The default StorageClass is annotated `storageclass.kubernetes.io/is-default-class: "true"` — `kubectl get storageclass` marks it with `(default)` next to its name.

</details>

<details><summary>Solution</summary>

```
kubectl get storageclass
```{{exec}}

Take the name shown next to `(default)` and write it to the file, e.g. if it's `local-path`:

```
echo "local-path" > /root/default-sc.txt
```{{exec}}

</details>
