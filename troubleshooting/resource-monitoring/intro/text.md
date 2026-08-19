
<br>

"Monitor cluster and application resource usage" is explicit CKA Troubleshooting content. This lab uses `kubectl top`, which needs `metrics-server` — not installed by default on a plain kubeadm cluster, so this scenario installs it for you before the first step. That takes a little while (image pull, plus one scrape interval before data appears) — hang tight.
