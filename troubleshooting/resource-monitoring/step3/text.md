
Node memory usage is elevated. Identify which Pod in the `default` namespace is responsible using `kubectl top`, and remove **only that one** to relieve the pressure — leave the other Pod running.

<br>

<details><summary>Tip</summary>

```
kubectl top node
kubectl top pod --sort-by=memory
```{{exec}}

</details>

<details><summary>Solution</summary>

```
kubectl top pod --sort-by=memory
```{{exec}}

The heaviest one is the answer:

```
kubectl delete pod mem-hog
```{{exec}}

```
kubectl top node
```{{exec}}

</details>
