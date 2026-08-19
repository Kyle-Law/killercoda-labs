
Disaster struck: `important-data` was accidentally deleted, and an unrelated change (`post-snapshot-junk`) got made afterward too. Restore the cluster's `etcd` state from the snapshot you took in the previous step, so `important-data` comes back — and `post-snapshot-junk` disappears, proving you actually rolled back state rather than just recreating things by hand.

<br>

<details><summary>Tip</summary>

```
kubectl get configmap important-data post-snapshot-junk
ls -la /etc/kubernetes/manifests/
grep -A3 'volumeMounts\|hostPath\|data-dir' /etc/kubernetes/manifests/etcd.yaml
```{{exec}}

The kubelet only manages static Pods whose manifest is in `/etc/kubernetes/manifests/` — moving a manifest out of that directory stops the Pod; moving it back starts it again.

</details>

<details><summary>Solution</summary>

Stop the control plane by moving its static Pod manifests out, so nothing is writing to `etcd` mid-restore:

```
mkdir -p /root/manifests-backup
mv /etc/kubernetes/manifests/*.yaml /root/manifests-backup/
```{{exec}}

Give the kubelet a few seconds to stop the Pods, then restore the snapshot into a **new** data directory — never the live one:

```
ETCDCTL_API=3 etcdctl snapshot restore /root/etcd-snapshot.db \
  --data-dir=/var/lib/etcd-restored
```{{exec}}

Point `etcd`'s manifest at the restored data directory, then bring the control plane back:

```
sed -i 's#/var/lib/etcd#/var/lib/etcd-restored#' /root/manifests-backup/etcd.yaml
mv /root/manifests-backup/*.yaml /etc/kubernetes/manifests/
```{{exec}}

Give it a minute or two to come back up:

```
kubectl get configmap important-data post-snapshot-junk
```{{exec}}

</details>
