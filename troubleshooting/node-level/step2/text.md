
The node now shows `STATUS NotReady`. `kubectl` alone won't fix this one — something on the node's own operating system is broken. Investigate directly on the node and bring it back to `Ready`.

<br>

<details><summary>Tip</summary>

```
kubectl get nodes
systemctl status kubelet
journalctl -u kubelet -n 50 --no-pager
```{{exec}}

</details>

<details><summary>Solution</summary>

```
systemctl start kubelet
```{{exec}}

Give it a little time for a heartbeat to land, then:

```
kubectl get nodes
```{{exec}}

</details>
