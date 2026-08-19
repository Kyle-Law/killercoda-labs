
`kubectl` commands are timing out or refusing to connect. The `kube-apiserver` isn't healthy — and this time you can't use `kubectl` to diagnose it. Use `crictl` to inspect containers directly, and the static Pod manifest on disk, to find and fix the problem.

<br>

<details><summary>Tip</summary>

```
crictl ps -a | grep apiserver
```{{exec}}

```
crictl logs <container-id-from-above>
```{{exec}}

```
cat /etc/kubernetes/manifests/kube-apiserver.yaml
```{{exec}}

`journalctl -u kubelet -f` is also worth knowing for cases where the kubelet itself is struggling to start the static Pod at all.

</details>

<details><summary>Solution</summary>

The container logs show an invalid flag, e.g. `unknown flag: --totally-bogus-flag`. Remove that line, or restore from the backup taken before this step:

```
cp /root/kube-apiserver.yaml.orig /etc/kubernetes/manifests/kube-apiserver.yaml
```{{exec}}

The kubelet watches this directory and restarts the static Pod automatically — no `kubectl apply` needed, and none would work anyway while the apiserver is down. Give it a few seconds, then:

```
kubectl get nodes
```{{exec}}

</details>
