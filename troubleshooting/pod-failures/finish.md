
<br>

### Recap

| Symptom | Cause | Diagnostic | Fix technique |
|---|---|---|---|
| `CrashLoopBackOff` | container exits immediately | `logs --previous`, `describe` | get → edit → delete → reapply |
| `ImagePullBackOff` / `ErrImagePull` | bad image reference | `describe` → Events | `kubectl set image` (live-patchable) |
| Repeated restarts, `OOMKilled` | memory limit too low | `describe` → Last State → Reason | get → edit → delete → reapply |
| `Running` but `0/1` Ready | readiness probe misconfigured | `describe` → Events, `exec` + `wget` | get → edit → delete → reapply |

### WELL DONE!

The recurring move: most Pod fields are immutable once the Pod exists, so `kubectl get -o yaml`, fix the file, delete, reapply is the standard technique — `kubectl set image` is the notable exception.
