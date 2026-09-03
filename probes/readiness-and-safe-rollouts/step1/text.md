
`shop` is running v1 on four replicas behind a NodePort Service, and it works:

```plain
kubectl get deployment shop
hitshop 10
```{{exec}}

`hitshop N` sends N requests through the Service and counts successes — you'll use it throughout.

`/root/manifests/v2-broken.yaml` is a bad release. The container starts and stays up; it just never listens on port 9898. Nothing crashes, nothing exits, no image is missing — the process is simply not serving.

**Deploy it, and watch `kubectl rollout status` closely.** Note what it says and what its exit code is. Then measure what an actual user gets.

<br>

<details><summary>Tip</summary>

```plain
kubectl apply -f /root/manifests/v2-broken.yaml
kubectl rollout status deployment/shop; echo "exit code: $?"
```{{exec}}

Then `hitshop 20`, and compare against what `kubectl get deployment shop` claims about `READY` and `AVAILABLE`.

Before deciding Kubernetes is broken, check what the Pods were actually asked to prove:

```plain
kubectl get deployment shop -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}{"\n"}'
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
kubectl apply -f /root/manifests/v2-broken.yaml
kubectl rollout status deployment/shop; echo "exit code: $?"
```{{exec}}

> `deployment "shop" successfully rolled out` — **exit code 0**.

Give the last old Pods a few seconds to finish terminating before measuring — until they're gone they're still serving, and will mask the damage:

```plain
sleep 20
kubectl get deployment shop
hitshop 20
```{{exec}}

`4/4` ready, `4` available, and `OK=0 FAILED=20`. In a pipeline this deploy is green. Every user is getting a connection refused.

The reason is the empty readiness probe. With no readinessProbe defined, a container counts as **Ready the moment its process starts** — that is the entire test. `sleep 3600` starts just fine.

Everything downstream inherits that lie:

```plain
kubectl get endpointslice -l kubernetes.io/service-name=shop \
  -o jsonpath='{range .items[0].endpoints[*]}{.addresses[0]}  ready={.conditions.ready}{"\n"}{end}'
```{{exec}}

Four endpoints, all `ready=true`, none of them serving. `maxUnavailable` was obeyed perfectly throughout — it just had no way to know that "available" meant nothing here. A rolling update is only as safe as the question the readiness probe asks, and the default question is "did the process start?"

</details>
