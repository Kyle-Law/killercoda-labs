
The picker chooses a replica for every request. Find out what it chooses on.

Send sixty requests with a long, repeated system prompt, one at a time. Then send sixty with a short one. **The two runs behave completely differently**, and the configuration is identical for both.

```plain
igload 60 long 1
```{{exec}}

```plain
igload 60 same
```{{exec}}

Write down which replica took the long-prompt traffic, and why the short prompt did not concentrate the same way, to `/root/answers/step2.txt`.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

`igload` prints what each replica served **during that run only**, so you can read the split directly.

`long` sends a thirty-sentence system prompt with a unique question on the end. `same` sends the literal string `hello` every time — identical, so if the picker rewarded repetition you would expect it to concentrate even harder.

The scorers are listed in the picker's own configuration:

```plain
kubectl get cm vllm-qwen3-32b-epp -o yaml | sed -n '/schedulingProfiles/,$p' | head -12
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
igload 60 long 1
```{{exec}}

> ```
>   requests served, this run only:
>    vllm-qwen3-32b-7dc98b85fc-6dkqr      0
>    vllm-qwen3-32b-7dc98b85fc-d6lqr      60
>    vllm-qwen3-32b-7dc98b85fc-rtpjg      0
> ```

**Every single request went to one replica.** Two of the three did nothing at all.

That looks like a broken load balancer, and it is the opposite. Look at what the picker weighs:

```plain
kubectl get cm vllm-qwen3-32b-epp -o yaml | sed -n '/schedulingProfiles/,$p' | head -12
```{{exec}}

> ```
>   - pluginRef: queue-scorer
>     weight: 2
>   - pluginRef: kv-cache-utilization-scorer
>     weight: 2
>   - pluginRef: prefix-cache-scorer
>     weight: 3
> ```

The **prefix-cache scorer** asks: which replica has already seen the beginning of this prompt? A model server that has processed a prefix keeps its intermediate state cached, so sending the next request with that same prefix somewhere else means recomputing work that already exists. Concentrating is the *point*. The first request picked a replica arbitrarily; every one after that went where the cache already was.

Now the second run:

```plain
igload 60 same
```{{exec}}

> ```
>   requests served, this run only:
>    vllm-qwen3-32b-7dc98b85fc-6dkqr      17
>    vllm-qwen3-32b-7dc98b85fc-d6lqr      25
>    vllm-qwen3-32b-7dc98b85fc-rtpjg      18
> ```

**Sixty identical requests, spread evenly.** Nothing changed except the prompt, and this prompt is *more* repetitive than the last one.

The prefix scorer works on fixed-size blocks: the prompt is hashed in chunks and matched chunk by chunk. `hello` is five characters, smaller than one chunk, so there is no chunk to match and the prefix score is zero for every replica. With that term out of the picture the other scorers decide, and they see three identical idle replicas.

Record it, using the Pod name **`igload` printed with 60 next to it** — not a
guess, since which replica wins the first request is arbitrary:

```plain
OWNER=<paste-the-pod-name-from-the-long-run>
cat > /root/answers/step2.txt <<EOF
$OWNER took all 60 long-prompt requests: prefix-cache affinity, weight 3.
The short 'hello' prompt spread evenly because it is smaller than one hashed
prefix chunk, so no replica scores anything for it and the other scorers -- which
see three identical idle replicas -- decide instead.
EOF
cat /root/answers/step2.txt
```{{exec}}

> **Why this matters beyond this lab.** This is the shape of a whole class of false negatives. Someone tests prefix-aware routing with a short prompt, sees an even spread, and concludes the feature is off or broken — when the feature is working and the *test* was too small to exercise it. Any cache-aware system has a size below which it has nothing to say.

</details>
