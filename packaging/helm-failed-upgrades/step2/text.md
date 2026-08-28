
`podinfo2` starts at **2 replicas**. Run the same broken upgrade against it — `image.tag=6.5.4-does-not-exist` — keeping it at 2 replicas, but this time add `--wait --timeout 60s`.

The command will hang for up to a minute and then **exit with an error** — that's expected, not a mistake. Once it returns, check `helm status podinfo2`. Compare the STATUS to what `podinfo` showed in the last step.

<br>

<details><summary>Tip</summary>

```
helm upgrade --help | grep -B2 -A4 '\-\-timeout'
```{{exec}}

`--wait` blocks until the Deployment's readiness matches the chart's rollout expectations, or the timeout is hit — whichever comes first. Remember `--set` doesn't remember anything from the last upgrade — repeat `replicaCount=2` alongside the new `image.tag`.

**Why 2 replicas, specifically:** at `replicaCount: 1`, this chart's hardcoded rollout strategy (`maxUnavailable: 1`) lets Helm consider a Deployment "ready" the instant zero Pods are required to be up — which is always true. Try this same broken upgrade later against a single-replica release and `--wait` will report success in under three seconds, image failure and all. `--wait` only works as advertised once the deployment can't mathematically satisfy readiness with zero healthy Pods — i.e. `replicas > maxUnavailable`.

</details>

<details><summary>Solution</summary>

```
helm upgrade podinfo2 podinfo/podinfo --version 6.5.4 --set replicaCount=2 --set image.tag=6.5.4-does-not-exist --wait --timeout 60s
```{{exec}}

The command above exits non-zero after ~60s. That's the point.

```
helm status podinfo2
```{{exec}}

`STATUS: failed` — because this time Helm actually checked, instead of taking the API server's word for it.

</details>
