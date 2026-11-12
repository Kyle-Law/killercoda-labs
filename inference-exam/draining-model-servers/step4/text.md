The idea from step 3 was right; the mechanism was wrong. Kubernetes can wait before `SIGTERM` without running anything in the container: the preStop hook has a built-in `sleep` action that the kubelet performs itself.

```yaml
lifecycle:
  preStop:
    sleep:
      seconds: 60
```

Then do the arithmetic, because there are still two clocks and now they run one after the other. An answer in flight gets the **sleep**, and after it the server's own **30-second drain**, which starts at `SIGTERM` exactly as before. And everything from "this Pod is terminating" to `SIGKILL` counts against `terminationGracePeriodSeconds`, **including the hook**, so the grace period has to hold both.

**The task:** replace the `exec` hook on `chat` with the `sleep` action and choose the sleep and the grace period so that `drill`'s answer survives the restart: 100 chunks, `[DONE]`, curl exit `0`.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

A strategic merge patch *merges* `sleep` into the existing hook and leaves `exec` beside it, and the API server refuses that: `may not specify more than 1 handler type`. Replace the whole `lifecycle` instead:

```plain
kubectl patch deploy chat --type=json -p '[{"op":"replace","path":"/spec/template/spec/containers/0/lifecycle","value":{"preStop":{"sleep":{"seconds":60}}}}]'
kubectl rollout status deploy/chat
```{{exec}}

The drill's answer starts 5 seconds before the restart and lasts about 50. The sleep starts a few seconds after the restart, once the new Pod is Ready. Too short a sleep, and the drain's 30 seconds run out before the answer does. Too short a grace period, and the kubelet kills the server in the middle of its drain.

</details>

<details><summary>Solution</summary>

```plain
kubectl patch deploy chat --type=json -p '[{"op":"replace","path":"/spec/template/spec/containers/0/lifecycle","value":{"preStop":{"sleep":{"seconds":60}}}}]'
kubectl get deploy chat -o jsonpath='{.spec.template.spec.terminationGracePeriodSeconds}{"\n"}'
kubectl rollout status deploy/chat
```{{exec}}

The grace period is still 120 from step 2, which holds a 60-second sleep and the 30-second drain after it.

Run the drill in the background this time, and look at the Service while the old Pod sleeps. The drill will first wait for a minute: `rollout status` returned as soon as the new Pod was Ready, but the Pod your patch replaced is now sleeping for 60 seconds itself. That is the price of the fix, paid already. The loop below waits for the drill's stream to begin, then for the restart and a few seconds of sleep:

```plain
drill > /tmp/drill.out 2>&1 &
until grep -q streaming /tmp/drill.out; do sleep 1; done; sleep 15
kubectl get endpointslice -l kubernetes.io/service-name=chat \
  -o jsonpath='{range .items[*].endpoints[*]}{.targetRef.name}  ready={.conditions.ready} serving={.conditions.serving} terminating={.conditions.terminating}{"\n"}{end}'
llmstream 4
```{{exec}}

> ```
> chat-bb7d5c689-zltlh  ready=false serving=true terminating=true
> chat-6c9d8f7b44-x2kqp  ready=true serving=true terminating=false
> stream:  4/4 chunks   [DONE]: yes   finish_reason: stop   curl exit: 0   (2s)
> ```

The sleeping Pod is `terminating` and no longer `ready`, so the Service sends new requests to its replacement; the short answer above went there. The Pod is still `serving`, still finishing the long answer it already had. Nothing new reaches it, nothing in flight is interrupted.

```plain
wait; cat /tmp/drill.out
```{{exec}}

> ```
> stream:  100/100 chunks   [DONE]: yes   finish_reason: stop   curl exit: 0
> old Pod: chat-bb7d5c689-zltlh gone 61s after the restart
> ```

**The whole answer, through a deploy.** The sleep ran out at 60 seconds, the kubelet sent `SIGTERM`, the server found nothing in flight and exited at once: 61 seconds.

The two clocks add up, and they have to fit inside the third. Each of these was run on this lab:

| sleep | grace | Answer | Old Pod gone after |
|---|---|---|---|
| 5s | 120s | 92 of 100, cut: sleep plus drain ran out first | 45s |
| 20s | 120s | **complete**: the drain carried the last 20-odd seconds | 46s |
| 60s | 120s | **complete**, inside the sleep | 61s |
| 15s | 20s | 53 of 100, cut: `SIGKILL` arrived 5s into the drain | 23s |
| 60s | 30s | refused by the API server: `must be non-negative and less than terminationGracePeriodSeconds (30)` | n/a |

The API server checks that the sleep fits inside the grace period. It knows nothing about the server's drain, so a grace period that holds the sleep and not the drain is accepted, and cuts answers.

The cost is visible in the 61. Every termination now takes the full sleep, busy or idle, so a rollout of ten replicas, one at a time, takes ten minutes. Leaning on the server's drain is cheaper, as the 20-second row shows, but it only works as long as you know that drain's length, and here it was found in a log line. Size the sleep to the longest answer you actually serve (`max_tokens` times the time per output token, which your metrics already know), and the grace period to the sleep plus the drain.

</details>
