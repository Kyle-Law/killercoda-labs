
Bump `staging` from `2` replicas to `4`. `dev` and `prod` stay exactly as they are, in the same file, same values list — change one entry, leave the other two untouched.

Before you check, predict: does anything happen to `podinfo-dev` or `podinfo-prod`'s Pods at all?

<br>

<details><summary>Tip</summary>

Same file, same `kubectl apply` — only the `staging` entry's `replicaCount` changes. Helm re-renders all three child `Application` manifests every time, but Argo CD only *acts* on the ones whose rendered output actually differs from what's already live.

</details>

<details><summary>Solution</summary>

```
sed -i 's/replicaCount: 2/replicaCount: 4/' /root/app-of-apps.yaml
kubectl apply -f /root/app-of-apps.yaml
```{{exec}}

```
kubectl -n podinfo-staging get deployment podinfo-staging -o jsonpath='replicas: {.spec.replicas}{"\n"}'
kubectl -n podinfo-dev get pods -o jsonpath='{.items[0].metadata.creationTimestamp}{"\n"}'
kubectl -n podinfo-prod get pods -o jsonpath='{.items[0].metadata.creationTimestamp}{"\n"}'
```{{exec}}

`staging` is at `4`. `dev` and `prod`'s Pods carry the same `creationTimestamp` as before — nothing about them was ever re-applied, because nothing about their rendered manifests changed. One entry in a values list, one child affected; the other two never even see a diff.

</details>
