The HPA in place targets 50% CPU. Put load on the model server, a request every two seconds for a minute, which is about four times what one replica can serve:

```plain
llmload 2 30
```{{exec}}

Then watch what the autoscaler sees, and what the model server says about itself, for a minute or so:

```plain
kubectl get hpa chat
llmstats
```{{exec}}

**The task:** write down both readings in `/root/answers/step1`: what the HPA's CPU reading was, and how many requests were waiting, at the same moment.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

Run the two commands a few times, thirty seconds apart. The HPA's `TARGETS` column is the CPU reading as a percentage of the container's request (`50m`); `WAITING` in `llmstats` is the model server's own count.

```plain
kubectl get hpa chat -w
```{{exec}}

(Ctrl+C to stop watching.)

</details>

<details><summary>Solution</summary>

```plain
kubectl get hpa chat
llmstats
```{{exec}}

> ```
> NAME   REFERENCE         TARGETS        MINPODS   MAXPODS   REPLICAS   AGE
> chat   Deployment/chat   cpu: 8%/50%    1         5         1          4m
>
> POD                             CPU  RUNNING  WAITING
> chat-7b9f47b497-j8d8z            4m        1       23
> ```

**Twenty-three users waiting, four millicores of CPU.** The autoscaler sees a replica at 8% of its request and does exactly what it is configured to: nothing. Run it again and the queue is deeper while the CPU is flat or lower.

The replica is not idle. It is generating one answer at a time, as fast as it can, and `RUNNING` is pinned at its ceiling of 1. Generation on a real server happens on the GPU, and this simulator models the same thing: the process waits, and waiting costs no CPU. A CPU target measures the one resource this workload does not use.

```plain
cat > /root/answers/step1 <<'EOF'
HPA read cpu 8%/50% (4m) and stayed at 1 replica while 23 requests were waiting.
EOF
```{{exec}}

The queue you just built is still there, and will be for a few minutes: one replica clears one answer every 8.6 seconds. Leave it. The next step uses it.

</details>
