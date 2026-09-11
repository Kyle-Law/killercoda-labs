
<br>

`ckne/packet-path-with-linux-tools` follows a packet along a path that works. This lab is the other half: four paths that don't, and no clue which part is broken.

There is no Kubernetes here, deliberately. The environment is three Linux network namespaces wired together with veth pairs — a client, a router, and a server:

```plain
cli 10.10.1.2  ──vc0───vr0──  rtr  ──vr1───vs0──  10.10.2.2 srv
                 10.10.1.0/24      10.10.2.0/24    :8080
```

That is exactly what a Pod, a node and a Service are underneath, with the CNI, kube-proxy and the API server removed so that nothing can hide behind them. Every fault you'll diagnose here has a direct Kubernetes counterpart, and `finish.md` maps each one — but the skill being built is reading a packet's path with `ip`, `tcpdump` and `iptables`, which is the same on any Linux box.

Three of the four faults produce **an identical symptom from the client**: the request hangs and times out. They have nothing else in common. Telling them apart is the entire exercise.

Drive everything through the `netlab` command:

```plain
netlab test          run the standard probe
netlab status        show the topology and whether a fault is active
netlab cli ...       run a command inside the client namespace
netlab rtr ...       ... the router
netlab srv ...       ... the server
netlab reveal        give up and see the answer, plus how you should have found it
```

A fault is already injected. Try to diagnose each one yourself before reaching for `netlab reveal` — it is the answer key, not a hint.
