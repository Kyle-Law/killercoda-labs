
Pod `data-pod` is running. Write the text `important` into `/data.txt` **inside the container** — no volume involved, just the plain container filesystem. Then force the container to exit and restart, without deleting the Pod. Confirm `data-pod` still exists (same name — kubelet just replaced the container), but `/data.txt` is gone.

Once confirmed, write `confirmed` into `/root/lifecycle-confirmed.txt` on the node.

<br>

<details><summary>Tip</summary>

```
kubectl exec data-pod -- sh -c "echo important > /data.txt"
kubectl exec data-pod -- kill -9 1
```{{exec}}

Sending `SIGKILL` to PID 1 — the container's own init process — is enough to make the whole container exit. Give the kubelet a couple of seconds to start the replacement.

</details>

<details><summary>Solution</summary>

```
kubectl exec data-pod -- sh -c "echo important > /data.txt"
kubectl exec data-pod -- kill -9 1
```{{exec}}

```
kubectl get pod data-pod
kubectl exec data-pod -- cat /data.txt
```{{exec}}

The Pod is the same one — same name, `RESTARTS` incremented by one — but the file is gone, because the writable filesystem belonged to the container that just got replaced, not the Pod.

```
echo confirmed > /root/lifecycle-confirmed.txt
```{{exec}}

</details>
