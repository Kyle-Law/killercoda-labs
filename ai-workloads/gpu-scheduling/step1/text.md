
Confirm the node has no accelerators today:

```plain
kubectl describe node $(cat /root/nodename) | grep -A8 "^Capacity:"
```{{exec}}

No `nvidia.com/gpu` line — as expected, there's no GPU and no device plugin.

Now advertise **4** of them. Extended resources live on the node's `status` subresource, and the resource name contains a `/`, which must be escaped as `~1` in a JSON Patch path ([RFC 6901](https://tools.ietf.org/html/rfc6901)).

<br>

<details><summary>Info: this is not a trick</summary>

From the Kubernetes documentation on extended resources:

> "Extended resources are opaque to Kubernetes; Kubernetes does not know anything about what they are."

They require **no device plugin and no hardware**. A device plugin is simply a well-behaved program that performs this same advertisement on your behalf, having actually counted the hardware. Everything the scheduler does with `nvidia.com/gpu` from here on is identical either way.

</details>

<details><summary>Tip</summary>

```plain
kubectl patch node --help | grep -A3 subresource
```{{exec}}

`--subresource=status` lets `kubectl patch` reach the status subresource directly. Older material uses `kubectl proxy` plus `curl` for this; it isn't needed any more.

</details>

<details><summary>Solution</summary>

```plain
kubectl patch node $(cat /root/nodename) --subresource=status --type=json \
  -p '[{"op":"add","path":"/status/capacity/nvidia.com~1gpu","value":"4"}]'
```{{exec}}

```plain
kubectl describe node $(cat /root/nodename) | grep -A9 "^Capacity:"
```{{exec}}

It appears under both `Capacity` and `Allocatable`. As far as every other component is concerned, this node now has four GPUs.

</details>

<br>

> Extended resources set this way do not survive a kubelet restart. That never happens in this scenario, but it's worth knowing if the counter ever mysteriously disappears on a real cluster.
