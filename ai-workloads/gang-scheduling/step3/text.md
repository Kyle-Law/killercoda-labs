
Kueue needs to know what it's rationing. Create the three objects:

- a **ResourceFlavor** named `default-flavor` — one kind of hardware
- a **ClusterQueue** named `gpu-queue` with a nominal quota of **4** `nvidia.com/gpu`
- a **LocalQueue** named `team-queue` in `default`, pointing at it

<br>

<details><summary>Tip</summary>

```plain
kubectl explain clusterqueue.spec.resourceGroups
```{{exec}}

The quota lives under `resourceGroups[].flavors[].resources[].nominalQuota`, and the resource must also be listed in that group's `coveredResources`.

</details>

<details><summary>Solution</summary>

```plain
cat <<'YAML' | kubectl apply -f -
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: default-flavor
---
apiVersion: kueue.x-k8s.io/v1beta1
kind: ClusterQueue
metadata:
  name: gpu-queue
spec:
  namespaceSelector: {}
  resourceGroups:
    - coveredResources: ["nvidia.com/gpu"]
      flavors:
        - name: default-flavor
          resources:
            - name: "nvidia.com/gpu"
              nominalQuota: 4
---
apiVersion: kueue.x-k8s.io/v1beta1
kind: LocalQueue
metadata:
  name: team-queue
  namespace: default
spec:
  clusterQueue: gpu-queue
YAML
```{{exec}}

```plain
kubectl get clusterqueue gpu-queue -o wide
kubectl get localqueue team-queue
```{{exec}}

</details>

<br>

<details><summary>Info: nominal quota is a promise, not a limit on the node</summary>

`nominalQuota: 4` says *this queue may admit work totalling 4 GPUs at a time*. It is bookkeeping in Kueue, entirely separate from the node's actual 4 GPUs.

They should agree — but if you set the quota to 8 on a 4-GPU cluster, Kueue would happily admit 8 GPUs of work and hand the scheduler an impossible problem, recreating exactly the pending-Pod mess it exists to prevent. Quota is Kueue's model of your capacity, and it's your job to keep that model honest.

</details>
