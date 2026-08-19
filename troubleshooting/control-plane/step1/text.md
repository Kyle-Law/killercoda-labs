
New Pods you create are stuck `Pending` forever, even though the cluster has plenty of capacity. Something in the control plane isn't working. Investigate the `kube-scheduler` static Pod in the `kube-system` namespace, find the problem on disk, and fix it.

<br>

<details><summary>Tip</summary>

```
kubectl get pods -n kube-system -l component=kube-scheduler
kubectl logs -n kube-system -l component=kube-scheduler
```{{exec}}

Static Pods are defined by files the kubelet watches — check `/etc/kubernetes/manifests/`.

</details>

<details><summary>Solution</summary>

```
cat /etc/kubernetes/manifests/kube-scheduler.yaml
```{{exec}}

You'll find an invalid `--totally-bogus-flag=true` line. Remove it, or restore from the backup taken before this step:

```
cp /root/kube-scheduler.yaml.orig /etc/kubernetes/manifests/kube-scheduler.yaml
```{{exec}}

The kubelet notices the change and restarts the static Pod automatically — no `kubectl apply` needed.

```
kubectl get pods -n kube-system -l component=kube-scheduler
```{{exec}}

</details>
