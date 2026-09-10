
<br>

`kubectl` describes a cluster in its own vocabulary — Pods, Services, Endpoints — and that vocabulary is genuinely useful right up until a packet goes missing and none of those words can tell you where. At that point the only thing left that hasn't lied to you yet is Linux itself: `ip`, `tcpdump`, `iptables`. They don't know what a Pod is. They know interfaces, packets, and rules, which is exactly what a packet is made of.

This lab never asks `kubectl` where a packet went. It finds a Pod's interface on the host by its kernel-assigned index, watches one HTTP request cross it with `tcpdump`, and reads the exact `iptables` rule that turns a Service address into a Pod address — on a live connection, both ends captured at once.

Two things are running: `web`, with a Service in front of it, and `client`, a Pod to make requests from. Every technique here works identically on a cluster ten times this size, because none of it depends on the CNI, the number of nodes, or anything Kubernetes-specific at all — only on there being a Linux network namespace involved, which there always is.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
