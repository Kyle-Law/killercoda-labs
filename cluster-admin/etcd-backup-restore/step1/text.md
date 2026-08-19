
A ConfigMap named `important-data` exists and must be protected against disaster. Take a full `etcd` snapshot to `/root/etcd-snapshot.db`, authenticating with the cluster's `etcd` client certs.

<br>

<details><summary>Tip</summary>

```
cat /etc/kubernetes/manifests/etcd.yaml | grep -- '--cert-file\|--key-file\|--trusted-ca-file\|--listen-client-urls'
etcdctl version
```{{exec}}

`etcdctl snapshot save <path> --endpoints=... --cacert=... --cert=... --key=...` is the command. `ETCDCTL_API=3` is the default in modern `etcdctl`, but setting it explicitly never hurts.

</details>

<details><summary>Solution</summary>

```
ETCDCTL_API=3 etcdctl snapshot save /root/etcd-snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```{{exec}}

```
etcdctl snapshot status /root/etcd-snapshot.db --write-out=table
```{{exec}}

</details>
