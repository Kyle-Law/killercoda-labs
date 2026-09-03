
First confirm this cluster serves the DRA API:

```plain
kubectl api-resources --api-group=resource.k8s.io
```{{exec}}

You want to see `deviceclasses`, `resourceclaims`, `resourceclaimtemplates` and `resourceslices`. If that list is empty, the cluster predates DRA going GA and the rest of this scenario won't work:

```plain
kubectl version
```{{exec}}

<br>

Now install the example driver. The chart is published as an OCI artifact, so there's nothing to clone or build:

```plain
helm install dra-example-driver \
  oci://registry.k8s.io/dra-example-driver/charts/dra-example-driver \
  --version 0.4.0 \
  --create-namespace --namespace dra-example-driver \
  --wait --timeout 5m
```{{exec}}

```plain
kubectl get pods -n dra-example-driver
```{{exec}}

<br>

## Read the inventory

This is the part with no equivalent in the old model. The driver **publishes what it has**:

```plain
kubectl get resourceslice
```{{exec}}

```plain
kubectl get resourceslice -o yaml | head -60
```{{exec}}

Each device carries attributes and capacity:

```plain
kubectl get resourceslice -o jsonpath='{range .items[0].spec.devices[*]}{.name}{"  model="}{.attributes.model.string}{"  mem="}{.capacity.memory.value}{"\n"}{end}'
```{{exec}}

And a `DeviceClass` groups them into something claimable:

```plain
kubectl get deviceclass
```{{exec}}

<br>

<details><summary>Info: what actually changed</summary>

With extended resources the node advertises `nvidia.com/gpu: 4` — a number, and nothing else. The scheduler cannot answer "which GPU?", because there is no *which*.

With DRA the driver publishes a `ResourceSlice` describing each device individually: `gpu-0` with 80Gi and this UUID, `gpu-1` with 80Gi and that UUID. The scheduler now has an inventory it can reason about — which is what makes the next two steps possible.

</details>
