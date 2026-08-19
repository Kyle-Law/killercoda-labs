
<br>

### Recap

| Symptom | Cause | Where to look |
|---|---|---|
| No endpoints at all | Service `selector` doesn't match Pod labels | `kubectl get endpoints`, `--show-labels` |
| Endpoints exist, connections fail | Service `targetPort` doesn't match the container's actual port | `kubectl describe svc`, container `ports` |
| Endpoints and connections fine, names don't resolve | CoreDNS unhealthy or scaled down | `kubectl -n kube-system get deploy coredns` |

### WELL DONE!

Services are mutable — `kubectl apply` a corrected manifest and the fix takes effect immediately, no delete-and-recreate needed. That's the opposite of most Pod troubleshooting, and worth remembering as its own rule of thumb.
