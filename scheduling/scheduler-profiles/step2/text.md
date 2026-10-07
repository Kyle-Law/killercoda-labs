
Step 1 got the scheduler reading a file. Now use it.

The default scheduler **spreads**: it prefers the emptier node. For some workloads you want the opposite — fill one node before opening the next, so the rest can be switched off. That is a different *scoring strategy* for the same plugin, and a profile is how you give a Pod a scheduler with different settings without running a second scheduler.

**Add a second profile named `bin-packing`** next to the default one. Its `NodeResourcesFit` plugin should score with `scoringStrategy.type: MostAllocated` over `cpu` and `memory`. Then restart the scheduler.

Two Deployments are waiting in `/root`. They are identical — 12 replicas, each asking for 500m of CPU and 512Mi — except for who is asked to place them:

```plain
kubectl apply -f /root/spread.yaml -f /root/packed.yaml
```{{exec}}

How many of the twelve fake nodes does each one end up using?

```plain
for D in spread packed; do echo "$D: $(kubectl get pods -l app=$D -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u | wc -l) nodes"; done
```{{exec}}

**Done when `packed` uses at most two nodes and `spread` is still using eight or more.** The default profile has to keep behaving as it did.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

The shape of a profile — add this under `profiles:` in `/etc/kubernetes/scheduler-config.yaml`, and keep `default-scheduler` as a profile of its own:

```yaml
profiles:
- schedulerName: default-scheduler
- schedulerName: bin-packing
  pluginConfig:
  - name: NodeResourcesFit
    args:
      scoringStrategy:
        type: MostAllocated
        resources:
        - {name: cpu, weight: 1}
        - {name: memory, weight: 1}
```

Confirm the scheduler loaded it, rather than trusting the file:

```plain
configz | grep -o '"schedulerName":"[^"]*"'
```{{exec}}

If `packed` still uses twelve nodes, the profile is working and something else is deciding. **Ask the scheduler.** `--vmodule=schedule_one=10` makes it log every plugin's score for every node, for one source file only. Add the flag to the manifest (a manifest change restarts the Pod by itself), recreate the Pods, and for a replica that was not the first one placed, compare a node that already holds a replica with an empty one.

Pods that are already placed never move. A fix to the scheduler only applies to Pods placed after it.

</details>

<details><summary>Solution</summary>

```plain
cat > /etc/kubernetes/scheduler-config.yaml <<'YAML'
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: /etc/kubernetes/scheduler.conf
profiles:
- schedulerName: default-scheduler
- schedulerName: bin-packing
  pluginConfig:
  - name: NodeResourcesFit
    args:
      scoringStrategy:
        type: MostAllocated
        resources:
        - {name: cpu, weight: 1}
        - {name: memory, weight: 1}
YAML
restart-scheduler
kubectl apply -f /root/spread.yaml -f /root/packed.yaml
sleep 10
for D in spread packed; do echo "$D: $(kubectl get pods -l app=$D -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u | wc -l) nodes"; done
```{{exec}}

Twelve and twelve. The profile loaded — `configz` shows `MostAllocated` under `bin-packing` — and changed nothing you can see. Turn on the score log and ask why:

```plain
sed -i 's|^    - kube-scheduler$|    - kube-scheduler\n    - --vmodule=schedule_one=10|' /etc/kubernetes/manifests/kube-scheduler.yaml
sleep 25
kubectl delete -f /root/packed.yaml
kubectl apply -f /root/packed.yaml
sleep 10
POD=$(kubectl get pods -l app=packed -o name | tail -1 | cut -d/ -f2)
kubectl -n kube-system logs -l component=kube-scheduler --tail=-1 | grep "$POD" | grep 'Plugin scored' | grep -E 'NodeResourcesFit|PodTopologySpread' \
  | sed -E 's/.*plugin="([A-Za-z]+)" node="([^"]+)" score=([0-9]+).*/\2 \1 \3/' | sort
```{{exec}}

For a replica placed after the first, the nodes that already hold a `packed` replica score higher on `NodeResourcesFit` than the ones that do not. On one run it was **11 against 7**: `MostAllocated` is doing exactly what you asked, and it is worth four points. But `PodTopologySpread` scores those same nodes **146 to 172, against 200** for the ones that hold none. That plugin was never in your config. **The scheduler applies built-in spreading constraints to Pods that belong to a workload**, a Deployment's replicas for one, and not to a bare Pod, which `PodTopologySpread` skips. It votes with a weight of 2. Four points for packing against thirty to fifty for spreading: the emptier node wins, every time. Your numbers will differ with how many replicas are already placed, but the proportions will not.

The fix is to switch the default spreading **off for this profile only**, so the default profile is untouched:

```plain
cat > /etc/kubernetes/scheduler-config.yaml <<'YAML'
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: /etc/kubernetes/scheduler.conf
profiles:
- schedulerName: default-scheduler
- schedulerName: bin-packing
  pluginConfig:
  - name: NodeResourcesFit
    args:
      scoringStrategy:
        type: MostAllocated
        resources:
        - {name: cpu, weight: 1}
        - {name: memory, weight: 1}
  - name: PodTopologySpread
    args:
      defaultingType: List
      defaultConstraints: []
YAML
restart-scheduler
kubectl delete -f /root/packed.yaml
kubectl apply -f /root/packed.yaml
sleep 10
for D in spread packed; do echo "$D: $(kubectl get pods -l app=$D -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u | wc -l) nodes"; done
```{{exec}}

`defaultingType: List` replaces the built-in defaults with the list you give it, and the list is empty. `spread` still uses twelve nodes, because the `default-scheduler` profile still has the built-in constraints. `packed` is on one.

</details>
