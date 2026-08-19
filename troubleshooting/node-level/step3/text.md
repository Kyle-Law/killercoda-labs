
The node has gone `NotReady` again — but this time restarting the kubelet alone won't fix it. Something about how the kubelet authenticates to the API server is broken. Investigate and fix it.

<br>

<details><summary>Tip</summary>

```
journalctl -u kubelet -n 50 --no-pager
ls -la /etc/kubernetes/
```{{exec}}

Compare what you see here to the file the kubelet's systemd unit expects (check its config/args).

</details>

<details><summary>Solution</summary>

The kubelet's own kubeconfig is missing:

```
mv /root/kubelet.conf.orig /etc/kubernetes/kubelet.conf
systemctl restart kubelet
```{{exec}}

```
kubectl get nodes
```{{exec}}

</details>
