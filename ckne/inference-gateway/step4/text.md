
The fix is one number.

Bring the prefix-cache scorer's weight down so a queue can actually outweigh a cache hit, get the picker to pick it up, and prove the traffic spreads.

Then find out what happens to that change the next time anyone runs `helm upgrade`.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

The weights live in the picker's ConfigMap, and it only reads that file when it starts:

```plain
kubectl edit cm vllm-qwen3-32b-epp
kubectl rollout restart deploy vllm-qwen3-32b-epp
kubectl rollout status deploy vllm-qwen3-32b-epp
```

Give it a few seconds after the restart before sending load. The gateway consults the picker over gRPC on every request, and while the old Pod is going away and the new one is not yet resolved you will get `500`s.

</details>

<details><summary>Solution</summary>

Drop the prefix weight from 3 to 1:

```plain
kubectl get cm vllm-qwen3-32b-epp -o yaml | sed 's/weight: 3/weight: 1/' | kubectl apply -f -
kubectl get cm vllm-qwen3-32b-epp -o jsonpath='{.data.default-plugins\.yaml}' | tail -7
```{{exec}}

> Only the prefix scorer has weight 3 — queue and KV are both 2 — so a plain substitution
> hits the right line and nothing else.

```plain
kubectl rollout restart deploy vllm-qwen3-32b-epp
kubectl rollout status deploy vllm-qwen3-32b-epp
sleep 20
```{{exec}}

Now the same load that went 0 / 60 / 0:

```plain
igload 60 long 10
```{{exec}}

> ```
>    vllm-qwen3-32b-dbdcfd59c-5257c      20
>    vllm-qwen3-32b-dbdcfd59c-6jxzx      19
>    vllm-qwen3-32b-dbdcfd59c-f2h8n      21
> ```

**Even.** Redo the arithmetic and it is obvious why:

| | prefix ×1 | queue ×2 | KV ×2 | total |
|---|---|---|---|---|
| the owner, queue as bad as it can get | 1 | 0 | 2 | **3** |
| an idle replica | 0 | 2 | 2 | **4** |

Now a full queue costs more than the cache hit is worth, so load wins. Note what you have given up to get here: every request that lands on a replica without the prefix recomputes work that already existed somewhere else. Neither weighting is correct in the abstract — 3 is right for a workload of long shared system prompts against replicas that are never saturated, and wrong the moment they saturate.

<br>

<details><summary>Now the part that bites later</summary>

The chart owns that ConfigMap:

```plain
kubectl get cm vllm-qwen3-32b-epp -o jsonpath='{.metadata.annotations}' | tr ',' '\n' | grep helm
```{{exec}}

> `"meta.helm.sh/release-name":"vllm-qwen3-32b"`

**The next `helm upgrade` writes that file back to `weight: 3`.** No warning, no conflict — the chart is the owner and your edit was never recorded anywhere it looks. Routing quietly returns to sending everything at one replica, most likely during an unrelated version bump weeks later, and the change that caused it is not in the diff anyone reviews.

A weight you arrived at by experiment belongs in the values the chart is installed with, not in a `kubectl edit`:

```plain
helm get values vllm-qwen3-32b
```{{exec}}

</details>

</details>
