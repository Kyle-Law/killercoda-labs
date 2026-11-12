Step 4's average kept four idle replicas alive because one replica's queue was deep enough to hold it above target on its own. Now the other direction.

First let step 3's load finish; this prints its summary once it has:

```plain
cat /tmp/llmload.out
```{{exec}}

Then give the HPA a floor of five replicas and room to grow to ten, so it is free to scale either way:

```plain
kubectl patch hpa chat -p '{"spec":{"minReplicas":5,"maxReplicas":10}}'
kubectl rollout status deploy/chat
```{{exec}}

Wait until every replica's queue is empty (`llmstats`), then do what an unlucky routing decision does in production: send nine requests at once to **one** replica, and read the HPA about twenty seconds later. It needs that long to see the queue, and after much longer the replica has worked some of it off.

```plain
llmflood $(kubectl get pods -l app=chat -o jsonpath='{.items[0].metadata.name}') 9
sleep 20
llmstats
kubectl get hpa chat
```{{exec}}

**The task:** one replica has a queue of users waiting and the HPA, with headroom to spare, does nothing. Work out what the HPA's number is and why it does not move, and write it down in `/root/answers/step5`.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

The HPA sees exactly what the custom metrics API gives it, one value per Pod:

```plain
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1/namespaces/serve/pods/*/vllm:num_requests_waiting" \
  | grep -o '"name":"[^"]*"\|"value":"[^"]*"' | paste - -
```{{exec}}

Then look at what `AverageValue` does with those values.

</details>

<details><summary>Solution</summary>

The exact figures depend on how many replicas you have. With six, eight requests waiting on one replica read like this:

> ```
> POD                             CPU  RUNNING  WAITING
> chat-7b9f47b497-5pvcv            1m        1        8
> chat-7b9f47b497-7t2ls            1m        0        0
> chat-7b9f47b497-ffv8p            1m        0        0
> chat-7b9f47b497-glhdp            1m        0        0
> chat-7b9f47b497-jgj5x            1m        0        0
> chat-7b9f47b497-t5n2q            1m        0        0
>
> NAME   REFERENCE         TARGETS     MINPODS   MAXPODS   REPLICAS
> chat   Deployment/chat   1333m/2     5         10        6
> ```

and with nine, seven waiting read `777m/2`.

**One replica's queue, divided by the number of replicas.** Below the target of 2, so the HPA's answer is "fewer replicas, if anything", and the minimum is the only thing holding it where it is. The last user in that queue waits about a minute for an answer that takes nine seconds, and the autoscaler's view of the fleet is that it is comfortably under target.

`AverageValue` describes the **fleet**, and the fleet is fine: it has more capacity than demand. What it lacks is the right request on the right replica, and adding a sixth replica would not change where these nine requests went. Step 4 and this step are the same fact from both sides: the average that kept four idle replicas because of one deep queue is the average that hides one deep queue among idle replicas. Neither is a bug in the HPA. Both are the distribution of work, which the autoscaler cannot see and cannot change.

```plain
cat > /root/answers/step5 <<'EOF'
HPA reads 1333m/2: 8 waiting on one replica averaged over 6 replicas, below target.
An average over the fleet cannot see one replica drowning; spreading the work is the router's job.
EOF
```{{exec}}

</details>
