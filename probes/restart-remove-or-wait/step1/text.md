
A Deployment called `slow-starter` is running. It never becomes `READY 1/1`, and its restart count keeps climbing:

```plain
kubectl get pods -l app=slow-starter -w
```{{exec}}

Press `Ctrl+C` once you've watched it turn over a couple of times.

**Work out what is killing it** — and note that "the app is broken" is not the answer. Then **prove** the app is fine by making it reach `READY 1/1` *without* changing the application, its image, or its command.

<br>

<details><summary>Tip</summary>

```plain
kubectl describe pod -l app=slow-starter
```{{exec}}

Two things worth finding in that output: the `Exit Code` under **Last State**, and any `Unhealthy` warnings under **Events**. An exit code of `137` means the process was `SIGKILL`ed — it did not fall over on its own, something killed it.

Then look at what the container is actually told to run:

```plain
kubectl get deployment slow-starter -o jsonpath='{.spec.template.spec.containers[0].command}{"\n"}'
```{{exec}}

Compare how long that takes to start serving against how long the liveness probe is willing to wait: `initialDelaySeconds` plus `periodSeconds × failureThreshold`.

</details>

<details><summary>Solution</summary>

```plain
kubectl describe pod -l app=slow-starter | grep -E "Exit Code|Liveness|Unhealthy"
```{{exec}}

`Exit Code: 137`, and `Liveness probe failed: ... connect: connection refused`. The kubelet is killing the container.

The arithmetic: the command is `sleep 60 && ./podinfo`, so nothing listens on port 9898 for a full 60 seconds. The liveness probe waits `initialDelaySeconds: 5`, then probes every 3 seconds, and gives up after 2 failures — about **11 seconds**. Every restart begins the same 60-second startup, and gets killed at 11 seconds again. It can never win.

Prove the app is healthy by removing the probe that's killing it:

```plain
kubectl patch deployment slow-starter --type=json \
  -p '[{"op":"remove","path":"/spec/template/spec/containers/0/livenessProbe"}]'
```{{exec}}

```plain
kubectl rollout status deployment/slow-starter --timeout=150s
kubectl get pods -l app=slow-starter
```{{exec}}

`READY 1/1`, `RESTARTS 0`. Same image, same command, same 60-second startup — the application was never the problem. A liveness probe that was meant to protect against a hung app was itself the entire outage.

> Deleting the liveness probe is a diagnostic, not a fix — you've just given up detecting a genuinely hung container. Step 2 puts it back, correctly.

</details>
