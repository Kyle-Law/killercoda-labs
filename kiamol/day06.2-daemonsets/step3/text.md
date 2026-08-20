
Add a `nodeSelector` to `infra-agent` requiring the label `monitor: enabled` — no node currently has it. Confirm the DaemonSet's desired count drops to **zero**. That's not the same thing as Pods going `Pending`: the DaemonSet controller itself decides which nodes are eligible, so an unmatched node was never a candidate in the first place.

Then label exactly **one** of the two nodes with `monitor=enabled`, and confirm exactly one Pod appears — on that node.

<br>

<details><summary>Tip</summary>

```
kubectl explain daemonset.spec.template.spec.nodeSelector
```{{exec}}

A DaemonSet's `spec.template` is mutable — `kubectl apply`/`kubectl patch` on the DaemonSet itself, no delete-and-recreate needed here.

</details>

<details><summary>Solution</summary>

```
kubectl patch daemonset infra-agent --type merge -p '{"spec":{"template":{"spec":{"nodeSelector":{"monitor":"enabled"}}}}}'
```{{exec}}

```
kubectl get daemonset infra-agent
```{{exec}}

`DESIRED` is 0.

```
kubectl label node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') monitor=enabled
```{{exec}}

```
kubectl get daemonset infra-agent
kubectl get pod -l app=infra-agent -o wide
```{{exec}}

</details>
