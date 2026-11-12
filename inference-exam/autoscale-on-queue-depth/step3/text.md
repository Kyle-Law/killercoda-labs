The HPA now reads the queue. Make it work for its living: three minutes of the same load as before.

```plain
llmload 2 90
```{{exec}}

Watch it decide:

```plain
kubectl get hpa chat -w
```{{exec}}

(Ctrl+C to stop watching.)

**The task:** get the HPA to scale the Deployment up **on the queue metric**, and find the record it leaves of having done so: the record that says which metric made the decision.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

Every rescale is an event on the HPA, and the event's message gives the reason:

```plain
kubectl get events --field-selector involvedObject.kind=HorizontalPodAutoscaler
```{{exec}}

</details>

<details><summary>Solution</summary>

> ```
> NAME   REFERENCE         TARGETS       MINPODS   MAXPODS   REPLICAS
> chat   Deployment/chat   10750m/2      1         5         4
> chat   Deployment/chat   8200m/2       1         5         5
> ```

`10750m` is 10.75 requests waiting per replica against a target of 2, and **per replica** means averaged across the replicas the Deployment has at that moment. With 4 replicas that is about 43 requests waiting in total. Keep that in mind: the next two steps are about what an average can and cannot see. The HPA went from 1 to 4 replicas within about fifteen seconds, then to its maximum of 5.

```plain
kubectl get events --field-selector involvedObject.kind=HorizontalPodAutoscaler \
  -o custom-columns=REASON:.reason,MESSAGE:.message
```{{exec}}

> ```
> SuccessfulRescale   New size: 4; reason: pods metric vllm:num_requests_waiting above target
> SuccessfulRescale   New size: 5; reason: pods metric vllm:num_requests_waiting above target
> ```

**The event names the metric.** That is the line to look for when an HPA has more than one metric, or when you inherit one and want to know what is actually driving it. If the earlier events still show `FailedGetPodsMetric` from step 2, they record exactly how long this HPA could see nothing.

```plain
kubectl describe hpa chat | sed -n '/Conditions/,/Events/p'
```{{exec}}

`ScalingLimited=True TooManyReplicas`: it wanted more than 5 and was capped.

It scaled. Now look at whether that helped anyone.

</details>
