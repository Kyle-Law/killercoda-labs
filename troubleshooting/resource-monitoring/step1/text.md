
Two Pods are running in the `default` namespace, generating different amounts of load. Use `kubectl top` to determine which one is consuming more CPU right now, and write its name (nothing else) into `/root/top-cpu-pod.txt`.

<br>

<details><summary>Tip</summary>

```
kubectl top pod --sort-by=cpu
```{{exec}}

</details>

<details><summary>Solution</summary>

```
kubectl top pod --sort-by=cpu
```{{exec}}

The Pod listed first is the answer:

```
echo "high-cpu" > /root/top-cpu-pod.txt
```{{exec}}

</details>
