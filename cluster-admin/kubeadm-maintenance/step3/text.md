
Create a new bootstrap token for joining another node to this cluster, with a TTL of `2h` and description `ci-join-token`. Confirm it appears in `kubeadm token list`.

<br>

<details><summary>Tip</summary>

```
kubeadm token create --help
```{{exec}}

</details>

<details><summary>Solution</summary>

```
kubeadm token create --ttl 2h --description "ci-join-token"
```{{exec}}

```
kubeadm token list
```{{exec}}

</details>
