
Recover the outage first — roll back to v1 and confirm users are being served again.

Then give `shop` a readiness probe that asks a real question (`podinfo` serves `/readyz` on port 9898), and deploy the **exact same** broken release a second time. `/root/manifests/` has both manifests you need for that; `diff` them if you want to see that the only difference from step 1 is the probe.

Predict before you run it: does the rollout still finish? Do users still lose service? How many old Pods survive?

<br>

<details><summary>Tip</summary>

```plain
ls /root/manifests/
diff /root/manifests/v2-broken.yaml /root/manifests/v2-broken-probe.yaml
```{{exec}}

A probe lives in `spec.template`, so adding one *is* a rollout in its own right — recover to a healthy version with the probe in place first, then ship the bad one on top of it.

```plain
kubectl explain deployment.spec.strategy.rollingUpdate.maxUnavailable
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
kubectl apply -f /root/manifests/v1-probe.yaml
kubectl rollout status deployment/shop --timeout=180s
hitshop 10
```{{exec}}

Back to `OK=10 FAILED=0`, now with a readiness probe on every Pod. Ship the same broken release again:

```plain
kubectl apply -f /root/manifests/v2-broken-probe.yaml
```{{exec}}

Give it a minute to try, then look — no need to wait for `rollout status`, it isn't going to return:

```plain
sleep 60
kubectl get deployment shop
kubectl get pods -l app=shop
hitshop 20
```{{exec}}

`OK=20 FAILED=0`. The new Pods sit at `0/1 Running` and never become Ready, so `maxUnavailable` (25% of 4 = 1) only ever allows a single old Pod to be retired. Three old Pods keep serving, indefinitely, and the rollout simply stops making progress instead of completing.

Same broken release, same `maxUnavailable`, same everything else — the only difference is that "available" now means something. That is the entire job of a readiness probe during a deploy.

> `kubectl rollout status` will now sit there rather than exit. Better than lying, but still not a signal a pipeline can act on — step 4 fixes that.

</details>
