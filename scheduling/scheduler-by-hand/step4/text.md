
Your scheduler has no filters, and the real one has a dozen. When it is skipped, **who enforces those rules instead?** Find out for three of them.

First, **stop your loop**, so it does not keep placing Pods on the node you are about to change:

```plain
pkill -f by-hand.sh
```{{exec}}

Now put Pods on the worker (its name is in `/root/worker`) **by naming it in the Pod's `spec.nodeName`**. That skips the scheduler exactly as a Binding does, and it is how `nodeName` has always worked. Do it once for each rule, with a Pod that breaks it:

1. **A `NoSchedule` taint** on the worker that the Pod does not tolerate.
2. **A `nodeSelector`** the worker does not satisfy — `disktype: ssd` will do.
3. **A `NoExecute` taint** on the worker that the Pod does not tolerate.

For each one, work out what happened to the Pod, and which component — if any — said no. Look at the Pod *and* at the events about it.

Then write into `/root/answers/step4` the **one rule of the three that nothing stopped**.

When you are done, **leave the worker with none of your taints on it.** The `NoExecute` one in particular evicts everything on the node that does not tolerate it — your own Pods, `web`, and anything in `kube-system` that is not built to ride it out. They come back when it is removed.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

A skeleton for each Pod. Add what the rule needs:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: rule-1
spec:
  nodeName: <the worker>
  containers:
  - name: c
    image: busybox:1.36
    command: ["sleep", "3600"]
```

A taint is `kubectl taint node <node> <key>=<value>:<effect>`, and a trailing `-` on the same arguments removes it. The *effect* is part of a taint's identity, so to change `NoSchedule` into `NoExecute` you remove one and add the other.

The Pod may not survive long enough to read its status. Events outlive the object they are about:

```plain
kubectl get events --field-selector involvedObject.name=<pod>
```

</details>

<details><summary>Solution</summary>

```plain
NODE=$(cat /root/worker)
```{{exec}}

**1 — `NoSchedule`.** A Pod with no toleration, put on a node that has the taint:

```plain
kubectl taint node $NODE dedicated=lab:NoSchedule
cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: rule-1
spec:
  nodeName: $NODE
  containers:
  - name: c
    image: busybox:1.36
    command: ["sleep", "3600"]
YAML
sleep 8
kubectl get pod rule-1 -o wide
```{{exec}}

It runs. **Nothing said no.** The kubelet does not check a `NoSchedule` taint, and the scheduler, which does, was never asked.

**2 — `nodeSelector`.**

```plain
cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: rule-2
spec:
  nodeName: $NODE
  nodeSelector:
    disktype: ssd
  containers:
  - name: c
    image: busybox:1.36
    command: ["sleep", "3600"]
YAML
sleep 5
kubectl get pod rule-2
kubectl get pod rule-2 -o jsonpath='{.status.phase}{"  "}{.status.reason}{"\n"}{.status.message}{"\n"}'
```{{exec}}

The **kubelet** refuses it at admission: `Predicate NodeAffinity failed`. The Pod stays in the API, `Failed`, for you to read.

**3 — `NoExecute`.** Swap the taint:

```plain
kubectl taint node $NODE dedicated=lab:NoSchedule-
kubectl taint node $NODE dedicated=lab:NoExecute
cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: rule-3
spec:
  nodeName: $NODE
  containers:
  - name: c
    image: busybox:1.36
    command: ["sleep", "3600"]
YAML
sleep 6
kubectl get pod rule-3
kubectl get events --field-selector involvedObject.name=rule-3
```{{exec}}

The Pod is **gone**, and two different components said no: the kubelet (`TaintToleration`, `Predicate TaintToleration failed`) and the control plane's `taint-eviction-controller` (`TaintManagerEviction`, `Marking for deletion`). `NoExecute` is the one taint effect that is enforced *after* scheduling, which is why it is also the one that clears out Pods that were already there:

```plain
kubectl get pods -A -o wide --field-selector spec.nodeName=$NODE
```{{exec}}

Put it back, and write the answer:

```plain
kubectl taint node $NODE dedicated=lab:NoExecute-
echo NoSchedule > /root/answers/step4
```{{exec}}

</details>
