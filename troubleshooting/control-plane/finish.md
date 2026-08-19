
<br>

### Recap

| Component | Symptom | Diagnostic (kubectl works?) |
|---|---|---|
| `kube-scheduler` | new Pods stuck `Pending` | yes — `kubectl logs -n kube-system -l component=kube-scheduler` |
| `kube-controller-manager` | Deployments/ReplicaSets never reconcile | yes — `kubectl logs -n kube-system -l component=kube-controller-manager` |
| `kube-apiserver` | `kubectl` itself times out | **no** — `crictl ps -a`, `crictl logs`, `journalctl -u kubelet` |

### WELL DONE!

Static Pod manifests under `/etc/kubernetes/manifests/` are the kubelet's job, not the API server's — editing the file is always enough, and it's the *only* option once the API server itself is the thing that's broken.
