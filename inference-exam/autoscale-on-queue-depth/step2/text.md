The team runbook has the queue-based HPA ready to go. It replaces the CPU one, same name:

```plain
cat /root/hpa-queue.yaml
```{{exec}}

```plain
kubectl apply -f /root/hpa-queue.yaml
```{{exec}}

Give it thirty seconds, then look:

```plain
kubectl get hpa chat
```{{exec}}

**The task:** make the queue-based HPA work. It must stay a `Pods` metric on the queue depth, with the same target. Find out what the metric is really called where the HPA looks for it, fix `/root/hpa-queue.yaml`, and apply it.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

The HPA's conditions say what it tried:

```plain
kubectl describe hpa chat | sed -n '/Conditions/,$p'
```{{exec}}

It does not ask Prometheus. It asks the **custom metrics API**, which the adapter serves, and that API can be asked directly. It lists every metric it has:

```plain
kubectl get --raw /apis/custom.metrics.k8s.io/v1beta1 | grep -o '"name":"pods/[^"]*"' | head -20
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
kubectl get hpa chat
kubectl get hpa chat -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'
```{{exec}}

> ```
> chat   Deployment/chat   <unknown>/2   1     5     1     3m16s
> ScalingActive=False FailedGetPodsMetric: the HPA was unable to compute the replica count:
>   unable to get metric vllm_num_requests_waiting: unable to fetch metrics from custom
>   metrics API: the server could not find the metric vllm_num_requests_waiting for pods
> ```

The condition names the metric it could not find. Ask the API what it does have:

```plain
kubectl get --raw /apis/custom.metrics.k8s.io/v1beta1 | grep -o '"name":"pods/vllm[^"]*"'
```{{exec}}

> ```
> "name":"pods/vllm:cache_config_info"
> "name":"pods/vllm:kv_cache_usage_perc"
> "name":"pods/vllm:lora_requests_info"
> "name":"pods/vllm:num_requests_running"
> "name":"pods/vllm:num_requests_waiting"
> ```

**The colon is still there.** Prometheus metric names may contain colons, and most guides assume the adapter rewrites them to underscores on the way to the HPA. Its default rules do not: they pass the name through untouched. The runbook's name is a metric that does not exist, so the HPA has nothing to compute with and reports `<unknown>`. Nothing is in `Failed` state; it simply never scales.

Ask for the real one the way the HPA will:

```plain
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1/namespaces/serve/pods/*/vllm:num_requests_waiting" | head -c 400; echo
```{{exec}}

Fix the name and apply. The API server accepts the colon in an HPA metric name:

```plain
sed -i 's/name: vllm_num_requests_waiting/name: vllm:num_requests_waiting/' /root/hpa-queue.yaml
kubectl apply -f /root/hpa-queue.yaml
sleep 30
kubectl get hpa chat
```{{exec}}

If step 1's queue is still there, the HPA is already scaling. The next step is about what it does.

</details>
