
Extended resources are strictly exclusive: a GPU allocated to one Pod cannot be used by another, full stop. That's correct for training, and wasteful for a fleet of small inference services that each use a fraction of a card.

DRA separates the **claim** from the Pod. Create one `ResourceClaim` — not a template — and point two Pods at it. Both should land on the **same physical device**.

Clean up first so the difference is unambiguous:

```plain
kubectl delete pod pod0 pod-big pod-huge -n dra-demo --ignore-not-found
```{{exec}}

<br>

<details><summary>Solution</summary>

```plain
cat <<'YAML' | kubectl apply -f -
apiVersion: resource.k8s.io/v1
kind: ResourceClaim
metadata:
  namespace: dra-demo
  name: shared-gpu
spec:
  devices:
    requests:
      - name: gpu
        exactly:
          deviceClassName: gpu.example.com
---
apiVersion: v1
kind: Pod
metadata:
  namespace: dra-demo
  name: share0
spec:
  containers:
    - name: ctr0
      image: busybox:1.36
      command: ["sh", "-c", "env; sleep 3600"]
      resources:
        claims:
          - name: gpu
  resourceClaims:
    - name: gpu
      resourceClaimName: shared-gpu
---
apiVersion: v1
kind: Pod
metadata:
  namespace: dra-demo
  name: share1
spec:
  containers:
    - name: ctr0
      image: busybox:1.36
      command: ["sh", "-c", "env; sleep 3600"]
      resources:
        claims:
          - name: gpu
  resourceClaims:
    - name: gpu
      resourceClaimName: shared-gpu
YAML
```{{exec}}

```plain
kubectl wait --for=condition=Ready pod/share0 pod/share1 -n dra-demo --timeout=120s
kubectl get pods -n dra-demo
```{{exec}}

Now compare what each container received:

```plain
echo "share0: $(kubectl logs share0 -n dra-demo | grep GPU_DEVICE)"
echo "share1: $(kubectl logs share1 -n dra-demo | grep GPU_DEVICE)"
```{{exec}}

The same device, in both. And the claim records exactly who is using it:

```plain
kubectl get resourceclaim shared-gpu -n dra-demo -o jsonpath='{.status.reservedFor[*].name}{"\n"}'
```{{exec}}

</details>

<br>

<details><summary>Info: sharing is a policy decision, not an accident</summary>

`ResourceClaim` sharing is explicit — you create one claim and deliberately point several Pods at it. The alternative (`ResourceClaimTemplate`) gives every Pod its own device, which is the safe default.

That distinction is the whole point. Under extended resources the platform could only offer exclusive access, so fractional sharing needed vendor-specific machinery outside Kubernetes — MIG partitioning or time-slicing configured on the device plugin. Here it's an API-level choice the workload author makes, and the cluster records who holds what in `status.reservedFor`.

</details>
