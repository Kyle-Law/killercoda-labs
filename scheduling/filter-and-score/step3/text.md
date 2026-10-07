
A node affinity can be `required`, which filters, or `preferred`, which scores. A preferred term has a `weight` from 1 to 100, and 100 is the most you can ask for. It sounds like it should be a very strong wish. Find out how strong.

**1.** Start from a clean fleet. `reset-nodes`{{exec}} leaves twelve identical nodes with nothing on them, and `kwok-node-5` labelled `tier=gold`.

**2.** `/root/seekers.yaml` is six replicas that prefer `tier=gold` with **weight 100**. Apply it and see where they go:

```plain
kubectl apply -f /root/seekers.yaml
sleep 10
kubectl get pods -l app=seekers -o wide
```{{exec}}

**3.** Now put a **soft** taint on the gold node. `PreferNoSchedule` does not forbid anything; it asks the scheduler to avoid the node if it can. Recreate the Deployment (Pods that are placed never move) and see where they go now:

```plain
kubectl taint node kwok-node-5 soft=yes:PreferNoSchedule
kubectl delete -f /root/seekers.yaml
kubectl apply -f /root/seekers.yaml
```{{exec}}

**4.** Make all six land on `kwok-node-5` again — **without removing the taint, and without touching the preference.** Then write into `/root/answers/step3` which plugin outvoted the preference, and the two numbers that decided it:

```plain
echo "plugin=<name> gain=<what the preference was worth> cost=<what the taint cost>" > /root/answers/step3
```

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

The score log is still on from step 2. Pick one of the Pods that did *not* land on `kwok-node-5`, and compare the gold node with the one it chose:

```plain
POD=$(kubectl get pods -l app=seekers -o name | head -1 | cut -d/ -f2)
scores $POD kwok-node-5
scores $POD kwok-node-0
```{{exec}}

Find the two plugins whose scores differ most, and which way each points. Scores are weighted before they are logged.

A taint is something a Pod can tolerate. A toleration for a soft taint costs nothing and removes nothing.

</details>

<details><summary>Solution</summary>

```plain
reset-nodes
kubectl apply -f /root/seekers.yaml
sleep 10
kubectl get pods -l app=seekers -o wide --no-headers | awk '{print $7}' | sort | uniq -c
```{{exec}}

All six on `kwok-node-5`. The preference works. Now the soft taint:

```plain
kubectl taint node kwok-node-5 soft=yes:PreferNoSchedule
kubectl delete -f /root/seekers.yaml
kubectl apply -f /root/seekers.yaml
sleep 10
kubectl get pods -l app=seekers -o wide --no-headers | awk '{print $7}' | sort | uniq -c
POD=$(kubectl get pods -l app=seekers -o name | head -1 | cut -d/ -f2)
scores $POD kwok-node-5
scores $POD kwok-node-0
```{{exec}}

**None** of the six land on it. Compared with any other node, the gold node scores:

```
kwok-node-5:  NodeAffinity 200   TaintToleration   0   ...everything else equal...  TOTAL 572
kwok-node-0:  NodeAffinity   0   TaintToleration 300   ...everything else equal...  TOTAL 672
```

A `weight: 100` preference is worth **200**: 100, times `NodeAffinity`'s plugin weight of 2. One untolerated `PreferNoSchedule` taint costs **300**: `TaintToleration` scores the node with the most of them 0 and the rest 100, times *its* plugin weight of 3. **The most a preference can ask for is less than what one soft taint takes away**, so the preferred node loses by a hundred points before anything else is counted.

Tolerate the soft taint, and `TaintToleration` gives every node 300 again:

```plain
sed -i 's|^      tolerations:$|      tolerations:\n      - key: soft\n        operator: Exists|' /root/seekers.yaml
kubectl delete -f /root/seekers.yaml
kubectl apply -f /root/seekers.yaml
sleep 10
kubectl get pods -l app=seekers -o wide --no-headers | awk '{print $7}' | sort | uniq -c
echo "plugin=TaintToleration gain=200 cost=300" > /root/answers/step3
```{{exec}}

</details>
