
A Pod named `pull-pod` in the `default` namespace can't start — its container never leaves `Waiting`. Find out why, then fix the Pod so it reaches `STATUS Running`.

<br>

<details><summary>Tip</summary>

```
kubectl describe pod pull-pod
```{{exec}}

Check the `Events` section, and `.status.containerStatuses[0].state` for the exact waiting reason.

</details>

<details><summary>Solution</summary>

Unlike `command`, a Pod's container **image** can be live-patched:

```
kubectl set image pod/pull-pod app=busybox
```{{exec}}

</details>
