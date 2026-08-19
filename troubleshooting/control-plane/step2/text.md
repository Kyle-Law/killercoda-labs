
A Deployment named `web` exists in the `default` namespace, but `kubectl get pods` shows nothing running for it — not even a `ReplicaSet` was created. Something in the control plane isn't working. Investigate the `kube-controller-manager` static Pod, find the problem on disk, and fix it.

Once it's healthy, `web`'s ReplicaSet and Pods should appear on their own — you don't need to recreate anything.

<br>

<details><summary>Tip</summary>

```
kubectl get deployment web
kubectl get rs
kubectl get pods -n kube-system -l component=kube-controller-manager
kubectl logs -n kube-system -l component=kube-controller-manager
```{{exec}}

The Deployment→ReplicaSet→Pod chain is reconciled by controllers running inside `kube-controller-manager`. If it's down, objects you create just sit there un-reconciled.

</details>

<details><summary>Solution</summary>

```
cat /etc/kubernetes/manifests/kube-controller-manager.yaml
```{{exec}}

You'll find an invalid `--totally-bogus-flag=true` line. Remove it, or restore from the backup taken before this step:

```
cp /root/kube-controller-manager.yaml.orig /etc/kubernetes/manifests/kube-controller-manager.yaml
```{{exec}}

```
kubectl get pods -n kube-system -l component=kube-controller-manager
kubectl get rs
kubectl get pods
```{{exec}}

</details>
