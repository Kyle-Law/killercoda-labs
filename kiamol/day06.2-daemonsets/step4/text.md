
Set `infra-agent`'s `updateStrategy` to `OnDelete`. Then change its container image to `busybox:1.36`.

Observe that the running Pod is **untouched** — still `busybox:1.28` — even though the DaemonSet's spec has already changed. It stays that way until you manually delete it; only the replacement picks up the new image. Confirm that by deleting the Pod yourself and checking its replacement.

<br>

<details><summary>Tip</summary>

```
kubectl explain daemonset.spec.updateStrategy
```{{exec}}

The default strategy, `RollingUpdate`, is what makes a spec change propagate automatically — `OnDelete` is how you take manual control instead.

</details>

<details><summary>Solution</summary>

```
kubectl patch daemonset infra-agent --type merge -p '{"spec":{"updateStrategy":{"type":"OnDelete"}}}'
kubectl set image daemonset/infra-agent agent=busybox:1.36
```{{exec}}

```
kubectl get pod -l app=infra-agent -o jsonpath='{.items[0].spec.containers[0].image}'
```{{exec}}

Still `busybox:1.28`. Now delete it:

```
kubectl delete pod -l app=infra-agent
kubectl get pod -l app=infra-agent -o jsonpath='{.items[0].spec.containers[0].image}'
```{{exec}}

The replacement runs `busybox:1.36`.

</details>
