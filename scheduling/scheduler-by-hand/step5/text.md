
Your scheduler places Pods. It has never been asked whether they fit.

`/root/big.yaml` is a Deployment with two replicas, each asking for **1000 CPUs**. No node here has that, and your scheduler does not look.

1. Start your loop again — you stopped it in the last step.
2. Apply `/root/big.yaml`, and watch `kubectl get pods`.
3. **Make it stop.**
4. Write into `/root/answers/step5` **how many Pods were `Failed` at the moment you stopped it.**

Whatever you do to stop it, leave nothing running that is still creating more.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

```plain
kubectl get pods -l app=big
kubectl get pods --field-selector status.phase=Failed --no-headers | wc -l
```{{exec}}

Read why one of them failed:

```plain
kubectl get pod <one-of-them> -o jsonpath='{.status.phase}{"  "}{.status.reason}{"\n"}{.status.message}{"\n"}'
```

Two separate things are feeding each other here. Name them both before you decide which one to stop.

</details>

<details><summary>Solution</summary>

```plain
nohup /root/by-hand.sh > /root/by-hand.log 2>&1 &
kubectl apply -f /root/big.yaml
sleep 30
kubectl get pods -l app=big --no-headers | awk '{print $3}' | sort | uniq -c
```{{exec}}

Every one is `OutOfcpu`. The kubelet rejects each Pod at admission — `Pod was rejected: Node didn't have enough resource: cpu` — and a rejected Pod goes to phase `Failed` and **stays** there. Nothing reschedules it.

But the `ReplicaSet` counts only active Pods, so it sees one fewer than it wants and creates a replacement. Your loop sees an unplaced Pod, and binds it to the same node. The kubelet rejects that one. There is no back-off anywhere in the cycle, and it climbs by more than a Pod a second.

Count them, and stop it:

```plain
kubectl get pods --field-selector status.phase=Failed --no-headers | wc -l
pkill -f by-hand.sh
```{{exec}}

The real fixes are the two that break the cycle — a scheduler that filters on resources, or requests that fit. Killing the loop only stops the damage. Failed Pods are not cleaned up until the cluster holds 12500 of them (`--terminated-pod-gc-threshold`), so they stay until you remove the thing that owns them:

```plain
kubectl delete deployment big
```{{exec}}

Write down the count you saw:

```plain
echo <the number> > /root/answers/step5
```

</details>
