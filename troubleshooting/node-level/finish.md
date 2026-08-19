
<br>

### Recap

| Symptom | Cause | Fix lives in |
|---|---|---|
| Pods `Pending`, node `Ready` | node cordoned | `kubectl` (`uncordon`) |
| Node `NotReady`, kubelet stopped | `kubelet.service` down | `systemctl` |
| Node `NotReady`, kubelet running | kubelet can't authenticate to the API server | node filesystem (`/etc/kubernetes/kubelet.conf`) |

### WELL DONE!

"Something's wrong with the node" isn't one failure mode — the fix might be a `kubectl` command, a `systemctl` command, or a file on disk the kubelet depends on. `journalctl -u kubelet` is the throughline that tells you which.
