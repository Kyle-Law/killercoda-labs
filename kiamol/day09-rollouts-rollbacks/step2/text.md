
Two Deployments, two different constraints:

- `stateful-cache` corrupts its data if two versions of it are ever running at the same time. Configure its update strategy so the old version is **fully terminated** before any new Pod starts.
- `always-on` must never drop below its full Ready replica count (4) during a rollout — capacity can temporarily exceed 4, but must never go below it. Configure its `RollingUpdate` strategy accordingly, then trigger an update (change its image to `nginx:1.26-alpine`) and confirm it finishes with all 4 replicas Ready on the new image.

<br>

<details><summary>Tip</summary>

```
kubectl explain deployment.spec.strategy
kubectl explain deployment.spec.strategy.rollingUpdate
```{{exec}}

`maxUnavailable` and `maxSurge` accept either a percentage or an absolute number.

</details>

<details><summary>Solution</summary>

```
kubectl patch deployment stateful-cache --type merge -p '{"spec":{"strategy":{"type":"Recreate","rollingUpdate":null}}}'
```{{exec}}

```
kubectl patch deployment always-on --type merge -p '{"spec":{"strategy":{"type":"RollingUpdate","rollingUpdate":{"maxUnavailable":0,"maxSurge":1}}}}'
kubectl set image deployment/always-on nginx=nginx:1.26-alpine
kubectl rollout status deployment/always-on
```{{exec}}

</details>
