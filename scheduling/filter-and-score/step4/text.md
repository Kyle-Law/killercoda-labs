
At a dozen nodes the scheduler looks at every one of them. It does not at a few hundred, and nothing tells you.

**1.** `reset-nodes 250`{{exec}} — a clean fleet of 250 fake nodes. **This takes about a minute**, and the wait is the first thing to learn: a new node reports `Ready` at once, but carries a `node.kubernetes.io/not-ready` taint until the node lifecycle controller removes it, at about five nodes a second. A node with that taint is not a candidate for anything, so the helper waits until they have all gone.

**2.** The score log from step 2 prints about eight lines per node per Pod, which at 250 nodes is a flood. Lower it to the level that still prints the line you need next: `--vmodule=schedule_one=2`.

**3.** `/root/seekers20.yaml` is twenty replicas that prefer `kwok-node-5`, with weight 100. On a dozen nodes **18 of the 20** reach it: the other two are where default spreading wears the preference out. Apply it and count how many reach it now. Run it a few times (`kubectl delete -f`, then `apply -f`, because placed Pods never move). Does the count hold still?

**4.** For every Pod the scheduler logs how many nodes it found **feasible**. Read that number for these Pods, and write it down:

```plain
echo "feasible=<n>" > /root/answers/step4
```

**5.** Make the scheduler consider every node, with a setting in its config file, and run it again. **Done when the scheduler's running config says `percentageOfNodesToScore: 100`, the fleet is still 250 nodes, and at least 14 of the 20 reach `kwok-node-5`.**

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

The bind line carries the number:

```plain
kubectl -n kube-system logs -l component=kube-scheduler --tail=-1 | grep 'Successfully bound' | grep seekers20 | head -3
```{{exec}}

It is a `V(2)` line, which is why it is absent from the scheduler's log at default verbosity.

How is the number chosen? Below 100 nodes the scheduler considers all of them. Above it, it stops filtering once it has found a percentage of the nodes feasible, and scores only those, starting each time from where the last search left off. The percentage, when you do not set one, is **`50 − (number of nodes ÷ 125)`**, but never below 5%, and the count never below 100.

To count the gold node: `kubectl get pods -l app=seekers20 -o wide --no-headers | awk '$7=="kwok-node-5"' | wc -l`

The setting lives at the top level of `/etc/kubernetes/scheduler-config.yaml`. The scheduler only reads that file when it starts: `restart-scheduler`.

</details>

<details><summary>Solution</summary>

```plain
reset-nodes 250
sed -i 's/--vmodule=schedule_one=10/--vmodule=schedule_one=2/' /etc/kubernetes/manifests/kube-scheduler.yaml
sleep 25
kubectl -n kube-system wait --for=condition=Ready pod -l component=kube-scheduler --timeout=90s
kubectl apply -f /root/seekers20.yaml
sleep 15
kubectl get pods -l app=seekers20 -o wide --no-headers | awk '$7=="kwok-node-5"' | wc -l
kubectl -n kube-system logs -l component=kube-scheduler --tail=-1 | grep 'Successfully bound' | grep seekers20 | sed -E 's/.*(evaluatedNodes=[0-9]+ feasibleNodes=[0-9]+).*/\1/' | sort | uniq -c
```{{exec}}

Run the apply a few more times and the count wanders — somewhere between 6 and 11 of 20 — where at a dozen nodes it was 18 every time. And the log says:

```
evaluatedNodes=120 feasibleNodes=120
```

That is `50 − 251/125 = 48` percent of 251 nodes: **120**. The scheduler stopped filtering as soon as it had found 120 feasible nodes, so it *looked at* 120 of the 251 (that is `evaluatedNodes`), and scored only those. It starts each search where the last one ended, so the window moves, and the gold node is in it about half the time. **The scheduler picks the best node it looked at.** For the Pods whose window did not contain `kwok-node-5`, it was never a candidate, and nothing in the cluster says so.

```plain
echo "feasible=120" > /root/answers/step4
echo "percentageOfNodesToScore: 100" >> /etc/kubernetes/scheduler-config.yaml
restart-scheduler
kubectl delete -f /root/seekers20.yaml
kubectl apply -f /root/seekers20.yaml
sleep 15
kubectl get pods -l app=seekers20 -o wide --no-headers | awk '$7=="kwok-node-5"' | wc -l
kubectl -n kube-system logs -l component=kube-scheduler --tail=-1 | grep 'Successfully bound' | grep seekers20 | sed -E 's/.*(evaluatedNodes=[0-9]+ feasibleNodes=[0-9]+).*/\1/' | sort | uniq -c
```{{exec}}

Now `feasibleNodes=250`, and the count is **16, every time**. Not 18: with 250 more nodes to spread over, the gold node's lead wears out a little sooner. What changed is that the number stopped depending on where the window happened to be.

Put the fleet back when you are done:

```plain
reset-nodes
```{{exec}}

</details>
