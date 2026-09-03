
Install Kueue. It's a single manifest that adds its CRDs, a controller, and an admission webhook.

```plain
kubectl apply --server-side -f https://github.com/kubernetes-sigs/kueue/releases/download/v0.10.1/manifests.yaml
```{{exec}}

Wait for the controller to be ready — the webhook must be serving before any queue objects will be accepted:

```plain
kubectl wait --for=condition=Available --timeout=300s \
  deployment/kueue-controller-manager -n kueue-system
```{{exec}}

```plain
kubectl get pods -n kueue-system
kubectl get crds | grep kueue
```{{exec}}

<br>

<details><summary>Info: what Kueue adds</summary>

Kueue does not replace the scheduler. It sits **in front** of it, deciding *when* a job is allowed to be scheduled at all.

The three objects you'll use next:

| Object | Role |
|---|---|
| `ResourceFlavor` | a kind of hardware — e.g. "A100 nodes" vs "T4 nodes" |
| `ClusterQueue` | the pool and its quota, cluster-wide |
| `LocalQueue` | a namespace's entry point into a ClusterQueue |

A job is submitted **suspended**, with a label naming its LocalQueue. Kueue holds it until the full request fits, then unsuspends it. Only then does the normal scheduler see the Pods.

</details>

<br>

> `--server-side` is used because the CRDs are large enough to exceed the annotation size limit that client-side apply relies on.
