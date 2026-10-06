
Three Pods in the `default` namespace are `Pending`: `batch-1`, `batch-2` and `batch-3`.

```plain
kubectl get pods
```{{exec}}

They are `Pending` for three different reasons, and their names say nothing about which. One has been read by a scheduler, which refused it. One is being held back by something that has nothing to do with capacity. And one has **never been looked at by any scheduler at all**.

Find the one no scheduler has ever tried to place, and write its name into `/root/answers/step1`.

Work it out from what the cluster *says* about each Pod — its events and its status — rather than from what you were given to create them. The spec is the cheat. The status is the skill.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

A scheduler that tries and fails leaves evidence on the Pod. So does a gate. Compare all three:

```plain
kubectl describe pod batch-1 | tail -8
kubectl describe pod batch-2 | tail -8
kubectl describe pod batch-3 | tail -8
```{{exec}}

Events are only half of it. A Pod's status carries a list of conditions, and `PodScheduled` is the one a scheduler writes about:

```plain
kubectl get pod batch-1 -o jsonpath='{.status.conditions}{"\n"}'
kubectl get pod batch-2 -o jsonpath='{.status.conditions}{"\n"}'
kubectl get pod batch-3 -o jsonpath='{.status.conditions}{"\n"}'
```{{exec}}

</details>

<details><summary>Solution</summary>

It is `batch-1`.

`batch-3` has a `FailedScheduling` event: a scheduler read it, checked it against both nodes, and said no — the event lists why. `batch-2` has no event, but it has a condition: `PodScheduled` is `False` with reason `SchedulingGated`, and `kubectl get` prints `SchedulingGated` as its status. Something is deliberately holding it.

`batch-1` has **no events and no conditions at all**. It names a scheduler, `nightly-batch`, that no one is running, so nothing ever picked it up to fail.

```plain
kubectl get pod batch-1 -o jsonpath='{.spec.schedulerName}{"\n"}'
```{{exec}}

```plain
echo batch-1 > /root/answers/step1
```{{exec}}

The rule to keep: **no `FailedScheduling` event, and no `PodScheduled` condition, means no scheduler has tried** — which is the same symptom as a scheduler that is down.

</details>
