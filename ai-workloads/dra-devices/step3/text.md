
This is the capability the old model simply does not have.

With extended resources you can ask for *one GPU*. You cannot ask for **a GPU with at least 40Gi of memory**, because the cluster only ever knew a number.

DRA devices carry attributes, and a request can carry **CEL expressions** that filter on them.

**1.** Create a claim that selects a device by `model` **and** at least `40Gi` of memory, with a Pod to consume it. It should schedule.

**2.** Then create a second claim demanding something no device has — `200Gi` — and confirm that Pod stays `Pending` with its claim unallocated.

<br>

<details><summary>Tip: the attribute and capacity syntax</summary>

Attributes and capacity are namespaced by driver name:

```
device.attributes['gpu.example.com'].model == 'LATEST-GPU-MODEL'
device.capacity['gpu.example.com'].memory.compareTo(quantity('40Gi')) >= 0
```

Quantities are compared with `compareTo`, not `>=` directly. Look back at step 1's inventory for the attributes actually available.

</details>

<details><summary>Solution</summary>

```plain
cat <<'YAML' | kubectl apply -f -
apiVersion: resource.k8s.io/v1
kind: ResourceClaimTemplate
metadata:
  namespace: dra-demo
  name: big-gpu
spec:
  spec:
    devices:
      requests:
        - name: gpu
          exactly:
            deviceClassName: gpu.example.com
            selectors:
              - cel:
                  expression: "device.attributes['gpu.example.com'].model == 'LATEST-GPU-MODEL'"
              - cel:
                  expression: "device.capacity['gpu.example.com'].memory.compareTo(quantity('40Gi')) >= 0"
---
apiVersion: v1
kind: Pod
metadata:
  namespace: dra-demo
  name: pod-big
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
      resourceClaimTemplateName: big-gpu
YAML
```{{exec}}

```plain
kubectl wait --for=condition=Ready pod/pod-big -n dra-demo --timeout=120s
kubectl logs pod-big -n dra-demo | grep GPU_DEVICE
```{{exec}}

Now ask for something impossible:

```plain
cat <<'YAML' | kubectl apply -f -
apiVersion: resource.k8s.io/v1
kind: ResourceClaimTemplate
metadata:
  namespace: dra-demo
  name: huge-gpu
spec:
  spec:
    devices:
      requests:
        - name: gpu
          exactly:
            deviceClassName: gpu.example.com
            selectors:
              - cel:
                  expression: "device.capacity['gpu.example.com'].memory.compareTo(quantity('200Gi')) >= 0"
---
apiVersion: v1
kind: Pod
metadata:
  namespace: dra-demo
  name: pod-huge
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
      resourceClaimTemplateName: huge-gpu
YAML
```{{exec}}

```plain
sleep 20
kubectl get pods -n dra-demo
kubectl describe pod pod-huge -n dra-demo | grep -A5 Events
```{{exec}}

</details>

<br>

> Note the failure mode: `pod-huge` is `Pending` because **no device satisfies the expression** — not because the cluster is out of capacity. With an opaque counter those two situations are indistinguishable. Here they are entirely different problems, and the cluster can tell you which one you have.
