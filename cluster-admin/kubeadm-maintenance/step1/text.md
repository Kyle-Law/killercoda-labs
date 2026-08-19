
Create a `Role` named `log-reader` in the `default` namespace allowing `get` and `list` on `pods` and `pods/log`. Bind it to a **User** named `jane` — no ServiceAccount this time; a plain username, the way you'd bind access for a real person authenticating with a client certificate. Confirm with `kubectl auth can-i get pods/log --as=jane`.

<br>

<details><summary>Tip</summary>

```
kubectl create role log-reader --verb=get,list --resource=pods,pods/log --dry-run=client -o yaml
kubectl create rolebinding --help
```{{exec}}

A `RoleBinding`'s `subjects` can be `Kind: User`, `Kind: Group`, or `Kind: ServiceAccount` — `kubectl create rolebinding --user=` targets the first.

</details>

<details><summary>Solution</summary>

```
kubectl create role log-reader --verb=get,list --resource=pods,pods/log
kubectl create rolebinding jane-log-reader --role=log-reader --user=jane
```{{exec}}

```
kubectl auth can-i get pods/log --as=jane
```{{exec}}

</details>
