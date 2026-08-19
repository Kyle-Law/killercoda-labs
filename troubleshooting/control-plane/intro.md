
<br>

On a kubeadm cluster, the control plane itself runs as **static Pods** — defined by manifest files under `/etc/kubernetes/manifests/` that the kubelet watches directly. Edit one of those files and the kubelet restarts the Pod on its own; `kubectl apply` never enters into it.

This lab breaks `kube-scheduler`, `kube-controller-manager`, and `kube-apiserver` in turn. As you go, `kubectl` itself gets less reliable — by the last step it won't work at all, and you'll fall back to `crictl` and files on disk. That's the actual technique the CKA exam expects for this class of failure.
