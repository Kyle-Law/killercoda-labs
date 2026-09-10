
`web`'s Pod has an `eth0`, and the node this cluster runs on has some number of `veth*`-style interfaces. Exactly one of those host interfaces is the other end of `web`'s `eth0` — find out which.

Write its name to `/root/veth-web.txt`.

<br>

<details><summary>Tip</summary>

Look at the Pod's own interface first:

```plain
WEBPOD=$(kubectl get pod -l app=web -o jsonpath='{.items[0].metadata.name}')
kubectl exec $WEBPOD -- ip link show eth0
```{{exec}}

The name is followed by `@ifN` — that `N` is not decoration.

Every network interface on this node, host and Pods together, is numbered from one shared counter, because they're all just interfaces in the same kernel with different namespaces drawn around them. `@ifN` is the *veth pair's* other half, by that same number. Now look for it among the host's own interfaces:

```plain
ip link show
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
WEBPOD=$(kubectl get pod -l app=web -o jsonpath='{.items[0].metadata.name}')
kubectl exec $WEBPOD -- ip link show eth0
```{{exec}}

> ```
> 11: eth0@if15: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 65535 ...
> ```

Two numbers, and they mean different things. `11:` is this interface's *own* index — meaningless outside this Pod's network namespace, since every namespace numbers its interfaces from 1. `@if15` is its **peer's** index, and peer indexes are not namespace-local — they're allocated from one counter for the whole kernel, host included. Search for `15` among the host's interfaces:

```plain
ip link show | grep '^15:'
```{{exec}}

> ```
> 15: veth6bb15971@if11: <BROADCAST,MULTICAST,UP,LOWER_UP> ...
> ```

Interface 15 on the host, whose own peer is 11 — exactly `web`'s `eth0`. That confirms it both directions: the Pod's peer number points to the host interface, and the host interface's peer number points straight back.

```plain
echo veth6bb15971 > /root/veth-web.txt
```{{exec}}

**Every Pod on this node is, from the kernel's point of view, one end of an ordinary veth pair sitting in the host's default network namespace along with everything else.** The CNI's job was to create that pair and put one end in the Pod at startup — after that, it's just Linux networking, which is exactly why the standard Linux toolset can see and capture all of it.

> The number after `@if` will differ on your cluster and changes every time a Pod restarts. The technique — `ip link show eth0` inside the Pod, then match the number on the host — doesn't depend on any naming convention, which is what makes it work regardless of which CNI created the interface.

</details>
