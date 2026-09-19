
So far nothing has ever had to wait. The simulator answers instantly, so every replica's queue is empty, every queue score is identical, and the picker has never once had to weigh a cache hit against a backlog.

Give it that choice. Make the model servers slow enough to form a queue, then put the same long-prompt load through at a parallelism of ten and see where it goes.

Write what you find — **and the arithmetic that explains it** — to `/root/answers/step3.txt`.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

The simulator takes flags for first-token latency, per-token latency, and how many requests it will work on at once:

```plain
kubectl patch deploy vllm-qwen3-32b --type=json -p='[
 {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--time-to-first-token=500"},
 {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--inter-token-latency=50"},
 {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--max-num-seqs=2"}]'
kubectl rollout status deploy vllm-qwen3-32b
```{{exec}}

That rollout replaces all three Pods, so the picker's prefix table now refers to replicas that no longer exist. Send a serial run first to establish an owner again, *then* the parallel one — otherwise ten requests race to claim a cold table at once and two replicas end up sharing it, which muddles the result.

`igqueue` shows what each replica is doing right now. Run it while load is in flight, in a second terminal or backgrounded — afterwards everything has drained and looks fine.

</details>

<details><summary>Solution</summary>

```plain
kubectl patch deploy vllm-qwen3-32b --type=json -p='[
 {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--time-to-first-token=500"},
 {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--inter-token-latency=50"},
 {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--max-num-seqs=2"}]'
kubectl rollout status deploy vllm-qwen3-32b
```{{exec}}

Re-establish an owner on the new Pods, serially:

```plain
igload 30 long 1
```{{exec}}

> ```
>    vllm-qwen3-32b-dbdcfd59c-5257c       0
>    vllm-qwen3-32b-dbdcfd59c-6jxzx      30
>    vllm-qwen3-32b-dbdcfd59c-f2h8n       0
> ```

Now ten at a time, and watch the queue while it runs:

```plain
igload 60 long 10 > /tmp/run.txt 2>&1 &
sleep 6
igqueue
wait
cat /tmp/run.txt
```{{exec}}

> ```
> POD                                    RUNNING   WAITING       KV
> vllm-qwen3-32b-dbdcfd59c-5257c               0         0        0
> vllm-qwen3-32b-dbdcfd59c-6jxzx               2         8        0
> vllm-qwen3-32b-dbdcfd59c-f2h8n               0         0        0
>
>    vllm-qwen3-32b-dbdcfd59c-5257c       0
>    vllm-qwen3-32b-dbdcfd59c-6jxzx      60
>    vllm-qwen3-32b-dbdcfd59c-f2h8n       0
> ```

**Eight requests queued behind two in flight, while two replicas sit at zero and zero.** And the picker sent every one of the sixty there anyway.

This is not a bug, and nothing is misconfigured. Do the arithmetic:

Each scorer returns a value between 0 and 1, scored *relative to the other replicas*, and is then multiplied by its weight.

| | prefix ×3 | queue ×2 | KV ×2 | total |
|---|---|---|---|---|
| the owner, queue as bad as it can get | 1 × 3 = **3** | 0 × 2 = **0** | 1 × 2 = **2** | **5** |
| an idle replica, no cache at all | 0 × 3 = **0** | 1 × 2 = **2** | 1 × 2 = **2** | **4** |

**A queue can subtract at most 2 points. A prefix match is worth 3.** So queue depth cannot win — not at ten parallel requests, not at a hundred. The only term left that could tip it is KV-cache pressure, and the simulator's stays near zero.

```plain
cat > /root/answers/step3.txt <<'EOF'
The prefix owner keeps every request even with 8 waiting and two replicas idle.
Weights are prefix 3, queue 2, kv 2, and each scorer is 0-1 relative to the others.
Owner at worst: 3 + 0 + 2 = 5. Idle replica at best: 0 + 2 + 2 = 4.
A full queue only removes 2 points, and the prefix match is worth 3, so queue
depth can never outweigh it.
EOF
cat /root/answers/step3.txt
```{{exec}}

> **The thing to carry out of this lab.** The system is doing exactly what it was configured to do, there is no error anywhere, and the outcome is wrong for this workload. Queue depth is *visible* to the picker — it is scored, on every request — and it is structurally incapable of changing the decision. "It can see the metric" and "the metric can affect the outcome" are separate questions, and only the second one matters.

</details>
