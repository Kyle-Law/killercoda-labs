
A colleague has written the configuration they want in production, in `/root/team-config.yaml`. It adds the `bin-packing` profile, already carrying the fix from step 2, and sets `percentageOfNodesToScore: 50`.

```plain
cat /root/team-config.yaml
```{{exec}}

**Install it as the scheduler's config**, replacing yours, and restart the scheduler. Then confirm that **both** kinds of Pod still get a node — an ordinary one that names no scheduler, and one that asks for `bin-packing`:

```plain
kubectl apply -f /root/plain.yaml -f /root/packed-pod.yaml
kubectl get pods plain packed-pod -o wide
```{{exec}}

You are done when the scheduler is running the team's settings (check with `configz`) **and** both Pods have a node. If one does not, find out why and fix the config without removing `bin-packing`.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

A Pod that never gets a node has a symptom you have seen before. Look at what the cluster says about it:

```plain
kubectl describe pod plain | tail -5
kubectl get pod plain -o jsonpath='{.status.conditions}{"\n"}'
```{{exec}}

Then look at what the scheduler thinks it is responsible for, and at what a Pod that names no scheduler is actually asking for:

```plain
configz | grep -o '"schedulerName":"[^"]*"'
kubectl get pod plain -o jsonpath='{.spec.schedulerName}{"\n"}'
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
cp /root/team-config.yaml /etc/kubernetes/scheduler-config.yaml
restart-scheduler
kubectl apply -f /root/plain.yaml -f /root/packed-pod.yaml
sleep 15
kubectl get pods plain packed-pod -o wide
```{{exec}}

`packed-pod` is running. `plain` is `Pending`, with no events and no `PodScheduled` condition at all — the `batch-1` symptom from `scheduler-by-hand`: no scheduler has ever tried. The scheduler is healthy, and it logged nothing.

```plain
configz | grep -o '"schedulerName":"[^"]*"'
kubectl get pod plain -o jsonpath='{.spec.schedulerName}{"\n"}'
```{{exec}}

The running scheduler has **one** profile, `bin-packing`. A Pod that names no scheduler is given the name `default-scheduler`, and nothing here answers to it. **`profiles` is the whole list, not a list of additions.** A config that mentions only the new profile does not add it to the default one; it replaces it. And the scheduler does not treat a Pod nobody answers for as an error: it starts, it is healthy, and every ordinary Pod in the cluster is silently ignored.

```plain
sed -i 's/^profiles:$/profiles:\n- schedulerName: default-scheduler/' /etc/kubernetes/scheduler-config.yaml
restart-scheduler
sleep 10
kubectl get pods plain packed-pod -o wide
```{{exec}}

</details>
