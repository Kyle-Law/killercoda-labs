
You installed a Helm chart. Find out what that actually did to this node — it is a much smaller list than the chart makes it look.

Look at `/etc/cni/net.d` and `/opt/cni/bin` and answer:

- What happened to the config file you wrote in step 1, and who did it?
- Cilium's conflist is a third the size of yours and contains no IPAM section at all. Where did the addressing go?
- Both halves of the contract are on that node. Break the half you haven't broken yet, and predict the symptom before you look — it is not the one from step 1.

<br>

<details><summary>Tip</summary>

```plain
ls -la /etc/cni/net.d/
ls -1 /opt/cni/bin/
```{{exec}}

Compare the two configs side by side — your backed-up file is still there under a different name.

For the last part: step 1 had binaries and no config. You now have a config that names a binary. Move that binary somewhere else, create a Pod, and read the error carefully. Watch the **node** status too, and note how it differs from step 1.

Restarting the DaemonSet undoes it — installing that binary is one of the first things the agent does on startup.

</details>

<details><summary>Solution</summary>

```plain
ls -la /etc/cni/net.d/
```{{exec}}

> ```
> -rw-------  05-cilium.conflist
> -rw-r--r--  10-handmade.conflist.cilium_bak
> ```

**Cilium renamed your file.** Not out of tidiness: the kubelet reads the directory in lexical order and uses the first valid config it finds, so leaving two in place is how you get a node whose networking depends on a filename. Cilium's `cni.exclusive` setting (on by default) makes it claim the directory outright and move everyone else aside. Note that its own file is `05-`, which would have sorted ahead of your `10-` anyway — the rename is belt and braces.

```plain
cat /etc/cni/net.d/05-cilium.conflist
echo '--- yours, for comparison ---'
cat /etc/cni/net.d/10-handmade.conflist.cilium_bak
```{{exec}}

> ```
> {
>   "cniVersion": "0.3.1",
>   "name": "cilium",
>   "plugins": [
>     {
>        "type": "cilium-cni",
>        "enable-debug": false,
>        "log-file": "/var/run/cilium/cilium-cni.log"
>     }
>   ]
> }
> ```

One plugin, no IPAM, no ranges, no routes. Yours had to state the address range because `host-local` is a dumb allocator that only knows what the file tells it. `cilium-cni` doesn't need to be told: it asks the agent, which coordinates with every other node through the API server. **The addressing didn't disappear — it moved out of a static file on one node and into a component that can see the whole cluster.** That is the difference that lets a real CNI work across nodes at all.

The second half of the install is in the plugin directory:

```plain
ls -1 /opt/cni/bin/
```{{exec}}

> `cilium-cni` is new. The reference plugins from step 1 are untouched.

So "installing a CNI" put **one binary in `/opt/cni/bin` and one JSON file in `/etc/cni/net.d`**. Everything else the chart created — the agent, the operator, the CRDs — exists to keep those two things useful.

Both halves are load-bearing. Step 1 broke the config; break the binary:

```plain
mv /opt/cni/bin/cilium-cni /root/cilium-cni.bak
kubectl run binprobe --image=registry.k8s.io/e2e-test-images/agnhost:2.53 --command -- /bin/sh -c "sleep 3600"
sleep 20
kubectl get nodes
kubectl get pod binprobe
kubectl describe pod binprobe | sed -n '/Events:/,$p'
```{{exec}}

> ```
> ckne-control-plane   Ready    control-plane
> binprobe             0/1      ContainerCreating
>
> Warning  FailedCreatePodSandBox  ...  plugin type="cilium-cni" failed (add): failed to find plugin "cilium-cni" in path [/opt/cni/bin]
> ```

A different failure in three ways, and each one is a diagnostic:

| | step 1: no config | step 3: no binary |
|---|---|---|
| Node | `NotReady` | **`Ready`** |
| Pods | `Pending` — never scheduled | **`ContainerCreating`** — scheduled, then stuck |
| Message | `cni plugin not initialized` | `failed to find plugin ... in path` |

The node stays `Ready` because its config is valid — the kubelet has no way to know the binary it names is missing until something asks it to set up a Pod. So a cluster that is `Ready` but cannot start Pods is a *different* problem from one that never went `Ready`, and the two live in different directories.

Put it back:

```plain
kubectl -n kube-system rollout restart ds/cilium
kubectl -n kube-system rollout status ds/cilium --timeout=300s
ls -l /opt/cni/bin/cilium-cni
```{{exec}}

```plain
kubectl get pod binprobe -o wide
```{{exec}}

The agent reinstalled its own binary on startup, and the stuck Pod picked itself up — the kubelet had been retrying the sandbox the whole time. No restart, no re-create, no intervention.

```plain
kubectl delete pod binprobe --wait=false
```{{exec}}

</details>
