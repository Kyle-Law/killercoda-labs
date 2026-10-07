
The scheduler is configured by the flags in its static Pod manifest, `/etc/kubernetes/manifests/kube-scheduler.yaml`. Profiles cannot be written as flags, so it has to read a file.

`/etc/kubernetes/scheduler-config.yaml` already exists. It is valid, and it says nothing yet:

```plain
cat /etc/kubernetes/scheduler-config.yaml
```{{exec}}

**Make the scheduler read it.** You are done when `kube-scheduler` is `Ready` running with `--config`, and a new Pod gets a node.

Expect it not to work the first time, and not for one reason. While it is broken, every new Pod you create is `Pending` with no events, because the scheduler is not running to place it — which is also why `kubectl get pods -n kube-system` is the first place to look, and the scheduler's own log the second.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

The scheduler is a Pod. When it fails, read what it said before it died:

```plain
kubectl -n kube-system get pods -l component=kube-scheduler
kubectl -n kube-system logs -l component=kube-scheduler --tail=20
```{{exec}}

A static Pod only sees what its manifest mounts. Look at what this one mounts, and compare it with where your file is:

```plain
grep -n -B1 -A4 -E 'volumeMounts|hostPath' /etc/kubernetes/manifests/kube-scheduler.yaml
```{{exec}}

When the manifest changes, the kubelet recreates the Pod by itself. When only the config file changes, nothing restarts it: use `restart-scheduler`.

</details>

<details><summary>Solution</summary>

Add the flag:

```plain
sed -i 's|^    - kube-scheduler$|    - kube-scheduler\n    - --config=/etc/kubernetes/scheduler-config.yaml|' /etc/kubernetes/manifests/kube-scheduler.yaml
```{{exec}}

Wait for the kubelet to pick up the change, then read why it died:

```plain
sleep 25
kubectl -n kube-system get pods -l component=kube-scheduler
kubectl -n kube-system logs -l component=kube-scheduler --tail=5
```{{exec}}

```
open /etc/kubernetes/scheduler-config.yaml: no such file or directory
```

The file is on the host. It is not in the container: a static Pod gets only the `hostPath` volumes its manifest declares, and kubeadm declared exactly one, `scheduler.conf`. Mount the file:

```plain
sed -i '/^    volumeMounts:$/a\    - mountPath: /etc/kubernetes/scheduler-config.yaml\n      name: config\n      readOnly: true' /etc/kubernetes/manifests/kube-scheduler.yaml
sed -i '/^  volumes:$/a\  - hostPath:\n      path: /etc/kubernetes/scheduler-config.yaml\n      type: File\n    name: config' /etc/kubernetes/manifests/kube-scheduler.yaml
```{{exec}}

```plain
sleep 25
kubectl -n kube-system logs -l component=kube-scheduler --tail=5
```{{exec}}

```
Neither --kubeconfig nor --master was specified.  Using the inClusterConfig.  This might not work.
error creating inClusterConfig, falling back to default config: open /var/run/secrets/kubernetes.io/serviceaccount/token: no such file or directory
"command failed" err="invalid configuration: no configuration has been provided, try setting KUBERNETES_MASTER environment variable"
```

Read that against the manifest: `--kubeconfig=/etc/kubernetes/scheduler.conf` is on the command line, and the scheduler says it was not specified. The flag reference explains it: **`--kubeconfig` is ignored if a config file is specified in `--config`**, and so are `--kube-api-qps`, `--kube-api-burst`, `--kube-api-content-type`, `--profiling` and `--contention-profiling`. The manifest still shows the flag, pointing at a file that is still mounted, and the scheduler does not use it. The connection now has to come from the file:

```plain
cat >> /etc/kubernetes/scheduler-config.yaml <<'YAML'
clientConnection:
  kubeconfig: /etc/kubernetes/scheduler.conf
YAML
restart-scheduler
```{{exec}}

Now read back what the process is actually running, rather than what the file says:

```plain
configz | grep -o '"clientConnection":{[^}]*}'
```{{exec}}

</details>
