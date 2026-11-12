Five replicas, and the HPA is satisfied that it did its job. Look at the replicas themselves while the load is still running, or straight after:

```plain
llmstats
```{{exec}}

Run it a few times, thirty seconds apart.

**The task:** one replica is still holding a queue while others sit idle beside it. Work out which one it is and why the new replicas are not taking any of its work, and write that Pod's name to `/root/answers/step4`.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

Compare the Pods' ages with their queues:

```plain
kubectl get pods -l app=chat --sort-by=.metadata.creationTimestamp
```{{exec}}

Then ask where a request waits. The Service picks a replica when the connection is made, and the request is sent to that Pod. Once it is in that Pod's queue, is there anything that could move it?

</details>

<details><summary>Solution</summary>

```plain
llmstats
kubectl get pods -l app=chat --sort-by=.metadata.creationTimestamp
```{{exec}}

> ```
> POD                             CPU  RUNNING  WAITING
> chat-7b9f47b497-gh2dk            1m        0        0
> chat-7b9f47b497-j8d8z            2m        1       35
> chat-7b9f47b497-nqfft            1m        0        0
> chat-7b9f47b497-qsjnm            1m        0        0
> chat-7b9f47b497-xs52h            1m        0        0
> ```

A minute after the scale-up, four new replicas with nothing to do, and the original one with **35 requests waiting**. Two minutes after it, 28. It is draining at its own pace, one answer every 8.6 seconds, exactly as fast as it did when it was alone.

**A queued request has already been routed.** The Service chose a Pod when the connection was opened, and the request now sits inside that process's queue. Kubernetes has no way to take it back out and hand it to another replica, and nor does the client, which is waiting on a connection to that one Pod. The replicas the HPA added are real capacity, for requests that **have not arrived yet**. For everyone already in the queue, the scale-up changed nothing.

Two consequences worth carrying away:

- **Scaling on queue depth is still reactive.** By the time the queue says "add replicas", the users in it are already committed to the replica they queued on. A lower target, or a cap on how deep a replica will let its queue grow, means those users are fewer.
- **Spreading new work is a routing job.** A router that can see each replica's queue would have stopped sending requests to this one long before its queue reached 35. That is what [`ckne/inference-gateway`](https://killercoda.com/kylelaw/course/ckne/inference-gateway)'s endpoint picker does, and the Service in front of this Deployment does not.

```plain
kubectl get pods -l app=chat --sort-by=.metadata.creationTimestamp -o name | head -1 | cut -d/ -f2 > /root/answers/step4
cat /root/answers/step4
```{{exec}}

</details>
