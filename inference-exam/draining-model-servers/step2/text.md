The answer needs about 50 seconds and got 30. Give the old Pod more time than the whole answer takes.

**The task, part one:** set the `chat` Deployment's `terminationGracePeriodSeconds` to **at least 90**, wait for its rollout, and run `drill` again.

That should have fixed it. It did not. The old Pod did not use the time you gave it either: look at how long it lasted.

Something other than the kubelet closed that stream, and the old Pod is the only witness. Its log disappears with it, so you have to be listening *before* the drill starts.

**The task, part two:** catch the old Pod's log while it shuts down, find the line that explains why the answer was cut, and copy that line into `/root/answers/step2`.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

The field sits beside `containers` in the Pod template:

```plain
kubectl patch deploy chat -p '{"spec":{"template":{"spec":{"terminationGracePeriodSeconds":120}}}}'
kubectl rollout status deploy/chat
```{{exec}}

`kubectl logs -f` on a Deployment follows one of its Pods until that Pod's container exits. Start it in the background, writing to a file, then run the drill:

```plain
kubectl logs -f deploy/chat > /tmp/old.log 2>&1 &
```{{exec}}

The interesting part is at the end, after the shutdown signal arrives.

</details>

<details><summary>Solution</summary>

```plain
kubectl patch deploy chat -p '{"spec":{"template":{"spec":{"terminationGracePeriodSeconds":120}}}}'
kubectl rollout status deploy/chat
drill
```{{exec}}

> ```
> old Pod: chat-56958f559d-46t8w   grace: 120s   preStop: none
> stream:  82/100 chunks   [DONE]: no   finish_reason: none   curl exit: 18
> old Pod: chat-56958f559d-46t8w gone 37s after the restart
> ```

Cut again, a few tokens later, and the Pod was gone in 37 seconds with 120 available. **The process exited on its own.** Listen to it this time:

```plain
kubectl logs -f deploy/chat > /tmp/old.log 2>&1 &
drill
grep -E 'Shutdown|in-flight|Drain|HTTP shutdown' /tmp/old.log
```{{exec}}

> ```
> "Shutdown signal received, shutting down servers gracefully"
> "Waiting for all in-flight requests to finish"
> "Drain timed out, proceeding with shutdown" open_requests=1
> "HTTP shutdown timed out, forcing close"
> ```

The timestamps on those lines are 30 seconds apart, then 5 more:

```plain
grep -E 'Shutdown signal|Drain' /tmp/old.log | cut -c1-30
```{{exec}}

**The server has its own clock.** On `SIGTERM` it stops accepting work and waits for in-flight requests, for 30 seconds, then gives up and closes them. That timer is built into this simulator; `--help` lists no flag for it. Real model servers have their own equivalent, with their own default, and finding it is part of running one.

Now look again at step 1. The kubelet's limit was 30 seconds, and so is the server's. **Both clocks fired together**, and there was no way to tell which one cut the answer until you moved one of them. Moving the one you knew about only revealed the one you didn't.

```plain
grep -h 'Drain timed out' /tmp/old.log > /root/answers/step2
cat /root/answers/step2
```{{exec}}

You cannot change the server's clock here. But `SIGTERM` is what starts it, and that is something Kubernetes sends.

</details>
