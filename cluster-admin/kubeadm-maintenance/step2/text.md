
Routine maintenance: renew this cluster's `apiserver` certificate ahead of expiry. Use `kubeadm` to renew just that one certificate, and confirm its expiration date actually moved.

<br>

<details><summary>Tip</summary>

```
kubeadm certs check-expiration
kubeadm certs renew --help
```{{exec}}

</details>

<details><summary>Solution</summary>

```
kubeadm certs renew apiserver
```{{exec}}

```
kubeadm certs check-expiration | grep '^apiserver '
```{{exec}}

Compare that against `/root/apiserver-cert-before.txt` — the date and residual time should have moved. In a real cluster you'd also need to restart the `kube-apiserver` static Pod for it to pick up the renewed cert (moving its manifest out of `/etc/kubernetes/manifests/` and back, same as earlier in this series) — this step only checks the certificate file itself.

</details>
