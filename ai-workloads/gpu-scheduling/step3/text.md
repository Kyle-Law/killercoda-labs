
Four GPUs, two teams. Without quota, whoever applies first takes everything — which you just saw `trainer` do.

Clear the decks and divide the pool properly:

```plain
kubectl delete deployment trainer
```{{exec}}

**1.** Create namespaces `team-a` and `team-b`, each with a ResourceQuota named `gpu-quota` capping them at **2 GPUs**.

**2.** In `team-a`, try to create a Pod requesting **3** GPUs. Save the error to `/root/quota-error`.

<br>

<details><summary>Info: quota fails differently from scheduling</summary>

This is the distinction worth internalising:

| | When it fails | What you see |
|---|---|---|
| **Scheduler** (step 2) | after admission | Pod exists, sits `Pending` |
| **Quota** (this step) | at admission | **no Pod is created at all**, `kubectl` returns an error |

A Pending Pod is a capacity problem you discover by looking. A quota rejection is a policy problem that fails your `kubectl apply` immediately. Confusing the two sends you debugging the wrong layer.

</details>

<details><summary>Info: why only requests. and not limits.</summary>

For extended resources, only the `requests.` prefix is permitted in a quota. The Kubernetes docs are explicit about why:

> "As overcommit is not allowed for extended resources, it makes no sense to specify both `requests` and `limits` for the same extended resource in a quota."

Since requests and limits must be equal anyway, a `limits.nvidia.com/gpu` quota would be meaningless — so it's rejected.

</details>

<details><summary>Solution</summary>

```plain
kubectl create namespace team-a
kubectl create namespace team-b
```{{exec}}

```plain
for ns in team-a team-b; do
cat <<YAML | kubectl apply -n $ns -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: gpu-quota
spec:
  hard:
    requests.nvidia.com/gpu: "2"
YAML
done
```{{exec}}

```plain
kubectl get resourcequota -A
```{{exec}}

Now have `team-a` overreach:

```plain
kubectl run greedy -n team-a --image=busybox:1.36 --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"greedy","image":"busybox:1.36","resources":{"limits":{"nvidia.com/gpu":"3"}}}]}}' \
  --command -- sleep 3600 2>&1 | tee /root/quota-error
```{{exec}}

`exceeded quota` — and note that no Pod was created:

```plain
kubectl get pods -n team-a
```{{exec}}

Within quota it works fine:

```plain
kubectl run polite -n team-a --image=busybox:1.36 --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"polite","image":"busybox:1.36","resources":{"limits":{"nvidia.com/gpu":"2"}}}]}}' \
  --command -- sleep 3600
```{{exec}}

```plain
kubectl describe resourcequota gpu-quota -n team-a
```{{exec}}

</details>
