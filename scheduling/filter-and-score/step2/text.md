
Step 1 was about what the scheduler does when it **cannot** place a Pod. Now one that it can. Once the filters have removed the nodes that will not do, the scheduler *ranks* what is left, with a handful of plugins each casting a vote — and it will show its working, if you ask.

**1.** Ask. Give the scheduler `--vmodule=schedule_one=10` on its command line: score logging for **one source file**, not `-v=10` for everything, which is a flood. A manifest change restarts the Pod by itself; wait until it is `Ready`.

**2.** Create `scored`, a Pod that asks for nothing special:

```plain
kubectl apply -f /root/scored.yaml
kubectl get pod scored -o wide
```{{exec}}

**3.** Read what every plugin scored every node it considered — and note how few nodes that is, and why:

```plain
scores scored
```{{exec}}

**4.** Reproduce the final score of the node it landed on **by adding up its plugin scores yourself**, and check it against the `TOTAL` the scheduler logged. Then write two numbers into `/root/answers/step2`:

```plain
echo "score=<the winning node's TOTAL> weight=<TaintToleration's weight>" > /root/answers/step2
```

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

The flag goes in the scheduler's manifest, on the line after `- kube-scheduler`:

```plain
sed -i 's|^    - kube-scheduler$|    - kube-scheduler\n    - --vmodule=schedule_one=10|' /etc/kubernetes/manifests/kube-scheduler.yaml
kubectl -n kube-system get pods -l component=kube-scheduler -w
```{{exec}}

If you created `scored` before the scheduler was logging, the lines are not there: delete it and apply it again.

A plugin scores each node from 0 to 100. If a plugin logs something larger than that, what happened to the number between the plugin and the log?

</details>

<details><summary>Solution</summary>

```plain
sed -i 's|^    - kube-scheduler$|    - kube-scheduler\n    - --vmodule=schedule_one=10|' /etc/kubernetes/manifests/kube-scheduler.yaml
sleep 25
kubectl -n kube-system wait --for=condition=Ready pod -l component=kube-scheduler --timeout=90s
kubectl apply -f /root/scored.yaml
sleep 8
kubectl get pod scored -o wide
scores scored
```{{exec}}

Four nodes were scored, not thirteen. The other nine were filtered out before scoring began, for the reasons step 1 read: the eight tainted nodes, and the real node, which has no `type=kwok` label. Of the four that remain, two are empty (`kwok-node-8`, `-9`) and two hold a 7.5 CPU filler (`-6`, `-7`).

For the node it landed on, the plugins add up to the logged total:

```
TaintToleration 300 + NodeResourcesFit 98 + NodeResourcesBalancedAllocation 74 + VolumeBinding 0 + DynamicResources 0 + ImageLocality 0 = TOTAL 472
```

**The logged scores are already multiplied by the plugin's weight.** A plugin scores each node from 0 to 100, and `TaintToleration` logs **300** for a node with nothing wrong with it, which is 100 × a weight of **3**. That is why the arithmetic is a plain sum. The two fuller nodes lose on `NodeResourcesFit` (51 against 98, because it prefers nodes with more free) and so on the total (425 against 472).

Only six plugins voted. The ones with nothing to say about this Pod skip: it has no affinity for `NodeAffinity` to score, and no workload for `PodTopologySpread` to spread, so which plugins vote depends on the Pod.

```plain
echo "score=472 weight=3" > /root/answers/step2
```{{exec}}

(Use whatever total your node got; two empty nodes tie, and either may have won.)

</details>
