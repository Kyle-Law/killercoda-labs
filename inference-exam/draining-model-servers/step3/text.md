The server's 30 seconds start at `SIGTERM`. What comes *before* `SIGTERM` is up to you: a container's **preStop hook** runs first, and the kubelet sends the signal only when the hook returns. By the time it runs, the Pod is already out of the Service's endpoints, so no new request reaches it. A hook that just waits would let the answers in flight finish, with the server none the wiser.

The team runbook has the snippet for it, and it is the one you will find in most guides:

```yaml
lifecycle:
  preStop:
    exec:
      command: ["sleep", "60"]
```

**The task:** add that hook to the `sim` container of `chat`, exactly as written, and run `drill`. The result will not change. Find out what Kubernetes recorded about the hook and why it happened, and write the **reason** of the event it recorded (one word, the way `kubectl get events` shows it) to `/root/answers/step3`.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

```plain
kubectl patch deploy chat --type=strategic -p '{"spec":{"template":{"spec":{"containers":[{"name":"sim","lifecycle":{"preStop":{"exec":{"command":["sleep","60"]}}}}]}}}}'
kubectl rollout status deploy/chat
drill
```{{exec}}

Nothing in the Pod's status will look wrong; the Pod is gone anyway. The kubelet reports hook results as events:

```plain
kubectl get events --sort-by=.lastTimestamp | tail -8
```{{exec}}

The event names the failure and not its cause. To find the cause, run the hook's command yourself, in the same container image:

```plain
kubectl exec deploy/chat -- sleep 1
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
kubectl patch deploy chat --type=strategic -p '{"spec":{"template":{"spec":{"containers":[{"name":"sim","lifecycle":{"preStop":{"exec":{"command":["sleep","60"]}}}}]}}}}'
kubectl rollout status deploy/chat
drill
```{{exec}}

> ```
> old Pod: chat-5dbc94b-drqxc   grace: 120s   preStop: exec
> stream:  83/100 chunks   [DONE]: no   finish_reason: none   curl exit: 18
> old Pod: chat-5dbc94b-drqxc gone 38s after the restart
> ```

Identical to step 2. The Pod did not wait 60 seconds; it did not wait at all.

```plain
kubectl get events --sort-by=.lastTimestamp | grep -i prestop
```{{exec}}

> ```
> Warning   FailedPreStopHook   pod/chat-5dbc94b-drqxc   PreStopHook failed
> ```

**`FailedPreStopHook`, and that is all it says.** Then the kubelet did what it does after any hook, successful or not: it sent `SIGTERM`. The server started its 30-second drain at once, exactly as before. A failing preStop does not stop the Pod from terminating, it does not change its status, and it does not show up in `kubectl get pods`; it is one Warning event on a Pod that no longer exists.

Why it failed:

```plain
kubectl exec deploy/chat -- sleep 1
```{{exec}}

> ```
> exec: "sleep": executable file not found in $PATH
> ```

**The image has no `sleep`.** It has no shell either. It is a single Go binary on a minimal base, the way distroless and hardened images are built. An `exec` hook runs a command *inside the container*, so it can only use what the image ships, and the runbook snippet assumed a full operating system. It would have worked on an image that has one, which is why it is in the runbook: the same Deployment template moved to a slimmer image breaks with nothing but this event to show for it.

```plain
echo FailedPreStopHook > /root/answers/step3
```{{exec}}

</details>
