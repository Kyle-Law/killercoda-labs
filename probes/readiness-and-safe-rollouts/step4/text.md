
Put it together. Recover to v1, then configure `shop` so that deploying `v2-flapping.yaml` — the release that defeated a readiness probe in step 3 — **cannot drop a single request**, and reports itself as failed within about two minutes.

Four settings, three of which you've now met:

- a **readinessProbe** that asks a real question
- **minReadySeconds** longer than the 25 seconds a bad replica spends looking healthy
- **maxUnavailable: 0** — never retire a serving Pod on the promise of an unproven one
- **progressDeadlineSeconds** short enough that a pipeline finds out quickly

Then deploy the flapping release and prove both halves: `hitshop` never fails, and `kubectl rollout status` exits non-zero.

<br>

<details><summary>Tip</summary>

`minReadySeconds`, `progressDeadlineSeconds` and `strategy` all live on `spec`, **not** `spec.template` — so setting them doesn't itself trigger a rollout, and they'll still be in force when the next one starts.

With `maxUnavailable: 0` you need `maxSurge` of at least 1, or the rollout has no room to create anything.

Remember `v2-flapping.yaml` carries its own full spec; anything you set separately on `spec` survives it, but anything inside `spec.template` will be replaced by what's in that file.

</details>

<details><summary>Solution</summary>

```plain
kubectl apply -f /root/manifests/v1-probe.yaml
kubectl rollout status deployment/shop --timeout=180s
hitshop 10
```{{exec}}

Configure the safety settings — none of these are in `spec.template`, so they persist across the next deploy:

```plain
kubectl patch deployment shop --type merge -p '{
  "spec": {
    "minReadySeconds": 40,
    "progressDeadlineSeconds": 120,
    "strategy": {"rollingUpdate": {"maxUnavailable": 0, "maxSurge": 1}}
  }
}'
```{{exec}}

Now ship the release that took everything down last time:

```plain
kubectl apply -f /root/manifests/v2-flapping.yaml
kubectl rollout status deployment/shop; echo "exit code: $?"
```{{exec}}

> `error: deployment "shop" exceeded its progress deadline` — **exit code 1**.

```plain
kubectl get deployment shop
kubectl get deployment shop -o jsonpath='{range .status.conditions[*]}{.type}={.status} reason={.reason}{"\n"}{end}'
hitshop 20
```{{exec}}

`4/4` available, only `1` updated, `OK=20 FAILED=0`, and `Progressing=False` with reason `ProgressDeadlineExceeded`.

The bad release got exactly one Pod. That Pod became Ready, sat in its 40-second soak, broke at 25 seconds, and so never once counted as available. With `maxUnavailable: 0`, no healthy v1 Pod was ever retired waiting for it. The deploy failed loudly, in the pipeline, with none of it reaching a user.

Compare the three attempts at the same class of failure:

| | `rollout status` | users |
|---|---|---|
| step 1 — no readiness probe | exit `0`, "success" | total outage |
| step 3 — readiness probe only | exit `0`, "success" | total outage |
| here — all four settings | exit `1`, `ProgressDeadlineExceeded` | untouched |

</details>
