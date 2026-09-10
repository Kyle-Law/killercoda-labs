
Nothing in this cluster will start. Find out what the kubelet is actually complaining about, and answer three questions before you fix anything:

- Why is every ordinary Pod `Pending` rather than `ContainerCreating`?
- Why are `etcd`, `kube-apiserver` and `kube-proxy` still `Running`?
- The plugin binaries are already on the node. So what exactly is missing?

Then get the node to `Ready` **without installing any CNI software at all** — no Helm chart, no DaemonSet, no `kubectl apply` of anybody's manifest. Everything you need is already on disk.

<br>

<details><summary>Tip</summary>

`cnistate` prints the three things that decide whether this node has a pod network — what the kubelet thinks, what config is on disk, and which plugin binaries exist:

```plain
cnistate
```{{exec}}

The node's `Ready` condition message names the component that is unhappy. It is not the component that is missing.

For the last part: the kubelet doesn't load plugins, it reads a directory. Look at what's in `/opt/cni/bin` and ask what would have to exist for the kubelet to know which of those to run, and with what settings. A CNI's DaemonSet spends its life writing that answer into a file.

The address range this node is allowed to hand out is already decided, and it isn't the cluster CIDR:

```plain
kubectl get node -o jsonpath='{.items[0].spec.podCIDR}{"\n"}'
```{{exec}}

</details>

<details><summary>Solution</summary>

Start with what the kubelet says:

```plain
cnistate
kubectl get pods -A
```{{exec}}

> ```
> ckne-control-plane	False	KubeletNotReady
>   message: container runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:Network plugin returns error: cni plugin not initialized
> ```

Three things follow from that, and they answer the three questions:

- **`Pending`, not `ContainerCreating`.** A `NotReady` node carries the `node.kubernetes.io/not-ready:NoSchedule` taint, so the scheduler won't place anything on it. These Pods never got as far as needing a network — they never got a node.
- **The control plane is fine because it never uses the pod network.** `etcd`, `kube-apiserver`, `kube-scheduler`, `kube-controller-manager` and `kube-proxy` all run with `hostNetwork: true`, sharing the node's own address. That is the entire reason `kubectl` still works while the cluster is otherwise dead — and it's worth remembering as a diagnostic, because a cluster where *only* hostNetwork Pods are healthy is a cluster with a CNI problem.
- **`/opt/cni/bin` is populated, `/etc/cni/net.d` is empty.** The binaries were installed with the node. What's missing is the file that says which of them to run.

That file is the whole contract. The kubelet does not know what "Cilium" or "Calico" is; it reads the lowest-numbered `.conflist` in `/etc/cni/net.d` and executes the plugins it names. Write one yourself:

```plain
POD_CIDR=$(kubectl get node -o jsonpath='{.items[0].spec.podCIDR}')
echo "this node may allocate from $POD_CIDR"
cat > /etc/cni/net.d/10-handmade.conflist <<EOF
{
  "cniVersion": "0.3.1",
  "name": "handmade",
  "plugins": [
    {
      "type": "ptp",
      "ipMasq": true,
      "ipam": {
        "type": "host-local",
        "ranges": [ [ { "subnet": "$POD_CIDR" } ] ],
        "routes": [ { "dst": "0.0.0.0/0" } ]
      }
    }
  ]
}
EOF
cat /etc/cni/net.d/10-handmade.conflist
```{{exec}}

Three plugin names, one address range, no software:

- **`ptp`** creates a veth pair per Pod — one end in the Pod's network namespace, one on the host.
- **`host-local`** hands out addresses from `$POD_CIDR` and records them in a directory on this node.
- **`ipMasq`** adds a masquerade rule so Pods can reach things outside the cluster.

Nothing needs restarting. Watch:

```plain
kubectl get nodes -w
```{{exec}}

Once it flips to `Ready`, press `Ctrl+C` and look at what followed:

```plain
cnistate
kubectl get pods -A -o wide
```{{exec}}

The node is `Ready`, the taint is gone, the scheduler placed everything, and every Pod has an address out of `$POD_CIDR`. CoreDNS is up. You installed nothing.

> The `podCIDR` matters and it is not the cluster CIDR. `kube-controller-manager` runs with `--cluster-cidr` (a /16 here) and carves a per-node slice out of it (a /24), which it writes to `node.spec.podCIDR`. `host-local` allocating from that slice is what stops two nodes handing out the same address. On a real multi-node cluster, keeping every node's IPAM inside its own slice — and telling the other nodes how to reach it — is most of what a CNI does for a living.

</details>
