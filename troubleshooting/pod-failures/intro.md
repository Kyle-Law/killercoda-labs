
<br>

Troubleshooting is the single largest domain on the CKA exam (**30%**). Each step here drops a genuinely broken Pod into your cluster before you arrive — your job is to diagnose it with `kubectl describe`, `logs`, and `get events`, then fix it.

No YAML is handed to you. Only the symptom.

> Many Pod fields (`command`, `args`, probes, resource limits) can't be live-patched on a running Pod — the Kubernetes API rejects the edit. The real-world technique, and the one the exam expects, is: `kubectl get pod X -o yaml > file.yaml`, edit the file, `kubectl delete pod X`, `kubectl apply -f file.yaml`. A few fields (notably `image`) **are** live-patchable via `kubectl set image` — you'll use both techniques across this lab.
