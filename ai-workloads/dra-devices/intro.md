
<br>

In the classic model an accelerator is an **opaque integer**. A node says `nvidia.com/gpu: 4`, a Pod asks for `1`, and the scheduler decrements a counter. It works — but the cluster has no idea what a GPU *is*. Every GPU is interchangeable, exclusively owned, and indistinguishable from every other.

Real fleets aren't like that. They hold several accelerator generations with different memory sizes and interconnects, and plenty of workloads would happily share one device.

**Dynamic Resource Allocation (DRA)** replaces the counter with structured devices. A driver publishes an inventory of real devices carrying **attributes** — model, memory, UUID, index — and workloads describe what they need with a **CEL expression** rather than a number.

This scenario uses the upstream [`dra-example-driver`](https://github.com/kubernetes-sigs/dra-example-driver), which publishes **mock GPUs**. No hardware is involved, and every DRA object behaves exactly as it would against a real driver.

> **Requires Kubernetes 1.34+**, where DRA is GA as `resource.k8s.io/v1` — no feature gates needed. Step 1 checks this first and tells you if the cluster is too old.
