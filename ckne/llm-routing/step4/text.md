
You now know `chat-slow` drowns under load while `chat-fast` sits idle. The obvious response is to autoscale — add replicas when the fleet is busy.

So decide what "busy" means. Put load on again, watch `llmstats`, and write the metric an HPA should scale this workload on — plus the observation that rules out the usual one — to `/root/answers/step4.txt`.

<br>

<details><summary>Tip</summary>

```plain
llmload 0.4 40 20 > /tmp/load.out 2>&1 &
sleep 12
llmstats
```{{exec}}

The default `HorizontalPodAutoscaler` metric is CPU utilisation. Look at the `CPU_mCORES` column for the replica with a queue, and ask whether a CPU target would ever fire.

</details>

<details><summary>Solution</summary>

```plain
llmload 0.4 40 20 > /tmp/load.out 2>&1 &
sleep 12
llmstats
```{{exec}}

> ```
> POD                               CPU_mCORES   RUNNING   WAITING
> chat-fast-6ccf665b78-wgsk9                 4         1         0
> chat-slow-646fb77b4d-kcxz6                 0         1        10
> embed-6fdf786587-4spbq                     0         0         0
> ```

**Ten requests queued. Zero millicores of CPU.**

A `HorizontalPodAutoscaler` targeting 70% CPU would look at that replica — the one with a ten-deep backlog and users waiting 30+ seconds — and conclude it is doing nothing at all. It would never scale. It might even scale *down*.

That is not a quirk of this simulator; it is what real inference looks like. **Generation is GPU-bound, and the HPA's default metric measures the CPU.** The process spends its life waiting on an accelerator, so the one number every Kubernetes autoscaling tutorial reaches for is measuring the wrong resource entirely.

The signal that does describe load is the one the model server publishes about itself:

```plain
SLOW=$(kubectl get pod -l speed=slow -o jsonpath='{.items[0].status.podIP}')
kubectl exec cli -- curl -s "http://$SLOW:8000/metrics" | grep -E '^vllm:num_requests_(running|waiting)'
```{{exec}}

> ```
> vllm:num_requests_running{model_name="demo-model"} 1
> vllm:num_requests_waiting{model_name="demo-model"} 10
> ```

- **`vllm:num_requests_running`** — what it is working on now. Capped by `--max-num-seqs`, so it tells you the replica is busy but never that it is *overwhelmed*; it pins at the ceiling and stays there.
- **`vllm:num_requests_waiting`** — work that has arrived and **has not started**. This is the one. It is zero on a healthy replica, and every unit above zero is a user waiting.

```plain
cat > /root/answers/step4.txt <<'EOF'
Scale on vllm:num_requests_waiting (queue depth), not CPU.
Observed 10 requests waiting at ~0 millicores CPU: generation is GPU-bound,
so a CPU-target HPA never fires and may scale down under load.
EOF
cat /root/answers/step4.txt
```{{exec}}

Wiring it up needs a metrics pipeline that can read a Pod's Prometheus endpoint — `prometheus-adapter` for a `Pods`-type HPA metric, or KEDA's Prometheus scaler — and then the HPA is ordinary:

```yaml
metrics:
- type: Pods
  pods:
    metric:
      name: vllm_num_requests_waiting
    target:
      type: AverageValue
      averageValue: "2"     # more than ~2 queued per replica => add one
```

> **The thing worth carrying away.** Queue depth is a *leading* indicator: it rises before latency does, because a request must wait before it can be slow. Latency and error rate are lagging — by the time your p90 moves, the queue has been building for a while and users are already affected. Scale on the queue and you add capacity before anyone notices; scale on latency and you are always recovering from harm already done.

</details>
