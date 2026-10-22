# CKA: the difficult ones

Labs for the harder parts of the CKA exam, grouped by exam domain. They follow the repo's house style:
each is built around one finding a learner would not predict, usually a failure that is silent or
misleading, and avoids ground the topic folders already cover (`troubleshooting/`, `cluster-admin/`,
`storage/`, `netpol/`, `probes/`, `helm/`, `kustomize/`, `scheduling/`).

## Status

All design specs, with deliberately no `index.json`: Killercoda only indexes directories that have one,
so nothing unfinished here can be published by accident. **Four are specced, the rest are ideas.**

| Lab | Domain | Status | Finding |
|---|---|---|---|
| [`rbac-subresources`](rbac-subresources/) | Cluster Architecture | Spec: **ready**, two claims to resolve | `kubectl auth can-i get pods/log` says yes while `kubectl logs` is Forbidden: it parses `pods/log` as a Pod named `log` |
| [`hpa-without-requests`](hpa-without-requests/) | Workloads & Scheduling | Spec: steps 1-2 **ready**, 3-4 to resolve | One container without a CPU request breaks the whole HPA, and `kubectl top` still works |
| [`configmap-three-behaviours`](configmap-three-behaviours/) | Workloads & Scheduling | Spec: **ready**, two claims to resolve | Of three ways to consume one ConfigMap only the volume updates (about 89s), never `env` or `subPath` |
| [`broken-cluster-capstone`](broken-cluster-capstone/) | Troubleshooting | Spec: assembly, one fault **unverified** | Fix the scheduler first: it hides two of the other faults |

**Observed on a live cluster** (kind, Kubernetes v1.37.0) when writing the first three: every table of
results in those specs. Nothing in the ideas list below has been run.

## Ideas, by domain

**Troubleshooting (30%)**

- **Two faults, one symptom.** A Service fails because the selector is wrong *and* `targetPort` names a
  port the container does not declare; fixing either alone still fails. Teaches reading `EndpointSlice`
  after every change.
- **The node that is Ready and useless.** A wrong containerd socket in `kubeadm-flags.env`: the node
  flips `NotReady` later, and new Pods stick in `ContainerCreating`. Needs `journalctl` and `crictl`.
- **Disk pressure that evicts the wrong thing.** Two reclaim mechanisms on two thresholds. *Verify first.*
- **An apiserver that starts and serves nothing.** A bad `--etcd-servers` or etcd cert: the container is
  running and every request times out. Only `crictl logs` works.
- **Logs that are not there.** A crash-looping container with empty `kubectl logs`: read `--previous`, or
  the termination message (`FallbackToLogsOnError`).
- **DNS that fails one query in five.** One bad CoreDNS replica; query each Pod IP to find it.
- **[`broken-cluster-capstone`](broken-cluster-capstone/)**: four faults, one clock.
- **Context discipline.** Two kubeconfig contexts, and checks that fail if the change lands in the wrong
  cluster. *Verify first:* whether a backend can host two clusters.

**Cluster Architecture, Installation & Configuration (25%)**

- **[`rbac-subresources`](rbac-subresources/)**
- **A kubeadm upgrade whose drain will not finish.** A PodDisruptionBudget of `minAvailable: 100%` plus a
  bare Pod needing `--force`. The drain is the lab.
- **Restore etcd, then find what it did not bring back.** Objects created after the snapshot are gone but
  their containers keep running. *Verify first:* whether the kubelet reaps them at once.
- **A ServiceAccount token that worked yesterday.** Projected tokens are time- and audience-bound; the
  legacy Secret token is not. *Verify first:* the shortest expiry the apiserver will issue.
- **CRDs without their operator.** Custom resources apply cleanly and `status` stays empty forever.
- **Certificates that renewed and a control plane that did not notice.** `kubeadm certs renew`, then
  static Pods keep serving the old ones until restarted: the same trap
  [`scheduler-profiles`](../scheduling/scheduler-profiles/) found with the manifest and its config file.

**Services & Networking (20%)**

- **The Ingress that 404s behind a healthy controller.** `ingressClassName` names a class nobody watches,
  then two Ingresses where one path shadows another.
- **A NodePort reachable everywhere except where you test.** `externalTrafficPolicy: Local` on a node
  with no backend. *Verify first:* under the backend's Cilium with kube-proxy replacement; see
  [`ckne/README.md`](../ckne/README.md).
- **The headless Service a StatefulSet cannot find itself through.** `serviceName` names a non-headless
  Service, so `pod-0.svc` never resolves while the Pods run.
- Already covered, so cross-link rather than build: CNI install
  ([`ckne/cni-install-and-configure`](../ckne/cni-install-and-configure/)) and cross-namespace
  `HTTPRoute` with `ReferenceGrant` ([`ckne/httproute-in-depth`](../ckne/httproute-in-depth/)).

**Workloads & Scheduling (15%)**

- **[`hpa-without-requests`](hpa-without-requests/)**
- **[`configmap-three-behaviours`](configmap-three-behaviours/)**
- **A rollout stuck at 75%.** `maxUnavailable: 0` and a ResourceQuota with no room for the surge Pod; the
  reason is in the ReplicaSet's events, not the Deployment's.
- **Native sidecars and Job completion.** A Job with a classic sidecar never completes; the fix is
  `restartPolicy: Always` on an init container. *Verify first:* the version it went GA.

**Storage (10%)**

- **A PVC bound to the wrong PV.** `storageClassName: ""` and the field being absent mean different things.
- **`WaitForFirstConsumer` and the Pod that cannot schedule.** The error appears on the Pod, not the claim.
- **Reclaim policy.** `Retain` leaves the PV `Released` and a new claim will not bind until `claimRef` is
  cleared by hand.

## Where to start

`rbac-subresources` first: the highest exam value, no new components, and the finding is crisp. The
capstone last, because it reuses faults the other labs prove.

## Conventions

Same as everywhere else in this repo. See [`ckne/README.md`](../ckne/README.md) for the ones that bite:

- **Scenarios index exactly two levels deep.** A finished lab is `cka/<scenario>/index.json`, nothing deeper.
- **Every check must say what it wanted.** Each `verify.sh` writes its reason to `/root/.check`, and each
  init installs the `why` helper that prints it.
- **Every claim reproduced on a live cluster before it is written down.** The last three weeks of the
  `scheduling/` work are the argument: two spike claims did not survive a settled cluster.
