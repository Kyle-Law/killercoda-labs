
A readiness probe fixed the last release. It will not fix this one.

`/root/manifests/v2-flapping.yaml` has a readiness probe already — a correct one, on `/readyz`. The release serves properly for **25 seconds**, then stops being ready and never recovers. Long enough to pass a probe on the way in; useless immediately afterwards.

Roll back to a healthy v1, then deploy it and watch the whole thing through. **Do not stop at `rollout status`** — keep checking for a minute after it returns.

<br>

<details><summary>Tip</summary>

```plain
kubectl apply -f /root/manifests/v1-probe.yaml
kubectl rollout status deployment/shop --timeout=180s
kubectl apply -f /root/manifests/v2-flapping.yaml
kubectl rollout status deployment/shop; echo "exit code: $?"
```{{exec}}

Then wait, and watch `AVAILABLE` on the Deployment:

```plain
kubectl get deployment shop -w
```{{exec}}

The question to hold onto: at what exact moment does a Pod get counted towards the rollout's progress?

</details>

<details><summary>Solution</summary>

```plain
kubectl apply -f /root/manifests/v1-probe.yaml
kubectl rollout status deployment/shop --timeout=180s
hitshop 10
```{{exec}}

```plain
kubectl apply -f /root/manifests/v2-flapping.yaml
kubectl rollout status deployment/shop; echo "exit code: $?"
```{{exec}}

> `successfully rolled out` — **exit code 0** again, and this time with a perfectly good readiness probe in place.

```plain
sleep 40
kubectl get deployment shop
hitshop 20
```{{exec}}

`0/4` available. `OK=0 FAILED=20`. Every replica passed its readiness probe on the way in, was counted, allowed the next one to roll, and then quietly stopped serving — by which point there was nothing left to roll back to that hadn't already been replaced.

The gap is in what "available" means by default: a Pod counts the **instant** it first reports Ready. Ready for one second and Ready for an hour are indistinguishable to a rolling update.

`minReadySeconds` is the missing soak time — a Pod must stay continuously Ready for that long before it counts towards the rollout at all:

```plain
kubectl explain deployment.spec.minReadySeconds
```{{exec}}

Set it longer than the window in which a bad release still looks healthy, and a release like this one can never accumulate enough good replicas to finish. Step 4 puts that to work.

</details>
