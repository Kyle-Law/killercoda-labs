
`job` asks for one CPU, on a node labelled `tier: gold`. It has been `Pending` since the lab started.

```plain
kubectl get events --field-selector involvedObject.name=job
```{{exec}}

Read the message. It is a histogram: every node is counted once, under **one** reason. Account for all of them: the counts add up to the first number, which is thirteen — twelve fake nodes and the real one.

Now the part that is easy to miss. **The scheduler reports the first reason a node failed on, and stops.** A node that fails for two reasons only ever says one of them, and the other is true all along and never shown.

Eight nodes are reported as tainted. Some of them are also full, or missing the label. **Predict what the message will say once `job` tolerates the taint**, and write it into `/root/answers/step1` as how many nodes will say each:

```plain
echo "cpu=<n> selector=<n>" > /root/answers/step1
```

Then make `job` tolerate the taint and read the message again. **Done when the message agrees with your prediction.**

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

You need to know three things about each of the eight tainted nodes: whether it has the label, whether it is full, and — because only the *first* failing filter is reported — which of those the scheduler checks first.

```plain
kubectl get nodes -o custom-columns='NAME:.metadata.name,TAINTS:.spec.taints[*].key,TIER:.metadata.labels.tier'
kubectl get pods -l role=filler -o wide
```{{exec}}

The filters run in a fixed order. The ones that matter here: taints, then node affinity and selectors, then resources.

A Pod's tolerations can be added to in place; they cannot be changed or removed:

```plain
kubectl explain pod.spec.tolerations
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
kubectl get nodes -o custom-columns='NAME:.metadata.name,TAINTS:.spec.taints[*].key,TIER:.metadata.labels.tier'
kubectl get pods -l role=filler -o wide
```{{exec}}

The eight tainted nodes fall into three kinds:

| Nodes | Has `tier=gold` | Full | Will say once the taint is tolerated |
|---|---|---|---|
| 0, 1, 2 | yes | yes | `Insufficient cpu` |
| 3, 4, 5 | no | no | didn't match selector |
| 10, 11 | no | **yes** | didn't match selector |

The last row is the one that matters: those nodes are full *and* unlabelled, but **node affinity is checked before resources**, so they will say selector, not cpu. So:

- **cpu** = the 3 nodes of the first row, plus the 2 untainted full nodes that already said so = **5**
- **selector** = the 3 nodes of the second row and the 2 of the third, plus the 3 that already said so (two untainted unlabelled fake nodes, and the real node, which has no `type=kwok`) = **8**

```plain
echo "cpu=5 selector=8" > /root/answers/step1
kubectl patch pod job --type=json -p '[{"op":"add","path":"/spec/tolerations/-","value":{"key":"dedicated","operator":"Equal","value":"batch","effect":"NoSchedule"}}]'
sleep 10
kubectl get events --field-selector involvedObject.name=job --sort-by=.lastTimestamp | tail -2
```{{exec}}

```
0/13 nodes are available: 2 Insufficient cpu, 3 node(s) didn't match Pod's node affinity/selector, 8 node(s) had untolerated taint(s). preemption: 0/13 nodes are available: 11 Preemption is not helpful for scheduling, 2 No preemption victims found for incoming pod.
0/13 nodes are available: 5 Insufficient cpu, 8 node(s) didn't match Pod's node affinity/selector. preemption: 0/13 nodes are available: 5 No preemption victims found for incoming pod, 8 Preemption is not helpful for scheduling.
```

The `preemption:` half is the scheduler asking a second question of the same nodes: *would evicting something help?* For a taint or a selector it would not, so **"Preemption is not helpful"**. For a full node it could in principle, but the filler Pods have the same priority as `job`, so **"No preemption victims found"**. Eleven and two before; eight and five after.

</details>
