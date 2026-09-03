
A Pod doesn't request a number any more — it references a **claim**.

Create a `ResourceClaimTemplate` asking for one device from the `gpu.example.com` class, and a Pod that consumes it. Confirm the driver injected the device into the container.

<br>

<details><summary>Info: template vs claim</summary>

- **`ResourceClaimTemplate`** — each Pod using it gets its **own** claim, and therefore its own device. This is what you want for ordinary workloads.
- **`ResourceClaim`** — one concrete claim that Pods can **share**. That's step 4.

Note the two-level naming in the Pod spec: `spec.resourceClaims[].name` is a local alias, and the container refers to that alias in `resources.claims[].name`. The claim is declared once per Pod and can be consumed by several containers.

</details>

<details><summary>Solution</summary>

```plain
cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: dra-demo
---
apiVersion: resource.k8s.io/v1
kind: ResourceClaimTemplate
metadata:
  namespace: dra-demo
  name: single-gpu
spec:
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
  name: pod0
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
      resourceClaimTemplateName: single-gpu
YAML
```{{exec}}

```plain
kubectl wait --for=condition=Ready pod/pod0 -n dra-demo --timeout=120s
kubectl get pods -n dra-demo
```{{exec}}

The driver injects the allocated device into the container's environment:

```plain
kubectl logs pod0 -n dra-demo | grep GPU_DEVICE
```{{exec}}

And a claim was created for this Pod and allocated to a specific device:

```plain
kubectl get resourceclaim -n dra-demo
```{{exec}}

```plain
kubectl get resourceclaim -n dra-demo -o jsonpath='{.items[0].status.allocation.devices.results[*].device}{"\n"}'
```{{exec}}

</details>
