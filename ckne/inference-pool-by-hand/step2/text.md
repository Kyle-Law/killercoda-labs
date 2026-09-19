
The picker watches the cluster: the pool it serves, the Pods that pool selects, and a couple of other resources. Its RBAC is four lines you would copy from an example without reading.

Take one away and find out what happens.

Remove the `pods` rule from its `Role`, restart it, and watch. Write down **what state the picker ends up in** and **how you found out which permission was missing** to `/root/answers/step2.txt` — then put the rule back.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

```plain
kubectl get role llm-epp -o yaml
```{{exec}}

A rollout that never completes is a clue in itself. `kubectl rollout status` will sit there; `kubectl get pods -l app=llm-epp` shows what is actually happening.

`pickerlog` pulls the errors out of the picker's own output.

</details>

<details><summary>Solution</summary>

```plain
kubectl patch role llm-epp --type=json -p='[{"op":"remove","path":"/rules/2"}]'
kubectl rollout restart deploy llm-epp
sleep 30
kubectl get pods -l app=llm-epp
```{{exec}}

> ```
> NAME                       READY   STATUS    RESTARTS      AGE
> llm-epp-76bddf89bf-dzrjc   0/1     Running   1 (9s ago)    2m11s
> llm-epp-7dd56979b5-rtb5v   1/1     Running   0             4m04s
> ```

**The new Pod is `Running` and never becomes Ready.** Not `CrashLoopBackOff`, not `Error` — running, and failing its readiness probe forever.

```plain
pickerlog
```{{exec}}

> ```
>   "error":"failed to list *v1.Pod: pods is forbidden: User
>            \"system:serviceaccount:default:llm-epp\" cannot list resource \"pods\"..."
> ```

**That message exists in exactly one place.** The Deployment says `1/2 updated`. The Pod says `Running`. The events say `Unhealthy`. None of them mentions RBAC. The picker names the precise resource and verb it was refused, in its own log, and that is the whole diagnosis.

Now notice what the cluster did with that:

```plain
poolcall
```{{exec}}

> Still `http=200`.

**Traffic kept flowing the entire time.** The rollout stalled, so the old Ready Pod was never removed — a Deployment will not take down a working replica for one that cannot pass its probe. The picker refuses to serve rather than serving badly, and the rollout strategy turns that refusal into a stall instead of an outage.

That is the good case, and it depends entirely on there having been a working Pod already. The same mistake on a first install has nothing to fall back to.

```plain
kubectl patch role llm-epp --type=json -p='[{"op":"add","path":"/rules/-","value":{"apiGroups":[""],"resources":["pods"],"verbs":["get","watch","list"]}}]'
kubectl rollout status deploy llm-epp
```{{exec}}

```plain
cat > /root/answers/step2.txt <<'EOF'
Removing the pods rule left the picker Running but never Ready -- it fails its
readiness probe rather than crashing, so the rollout stalls and the old replica
keeps serving traffic.
The only place the cause appears is the picker's own log: "pods is forbidden ...
cannot list resource pods". No Deployment, Pod or event mentions RBAC at all.
EOF
cat /root/answers/step2.txt
```{{exec}}

> **Worth trying if you have time.** The other two rules behave the same way, and one of them is easy to miss: the picker also watches `inferenceobjectives` **and** `inferencemodelrewrites`. Plenty of published examples grant only the first, and a picker with that Role never starts.

</details>
