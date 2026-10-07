
`percentageOfNodesToScore: 50` tells the scheduler it may stop looking once it has found half the feasible nodes. That only matters above 100 nodes, but the team wants **every node scored**, and a colleague has sent the change as a one-liner:

```plain
sed -i 's/^percentageOfNodesToScore: 50$/percentageOfNodeToScore: 100/' /etc/kubernetes/scheduler-config.yaml
restart-scheduler
```{{exec}}

Run it. Your colleague says it works.

**Done when the scheduler's running config says `100`, both profiles are still there, and ordinary Pods still get a node.**

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

If `restart-scheduler` says the scheduler is not Ready, read what it said as it died:

```plain
kubectl -n kube-system get pods -l component=kube-scheduler
kubectl -n kube-system logs -l component=kube-scheduler --tail=5
```{{exec}}

While it is down, nothing is placing anything. Look at what a new Pod looks like in that state:

```plain
sed 's/name: plain$/name: plain-2/' /root/plain.yaml | kubectl apply -f -
kubectl get pod plain-2
kubectl get events --field-selector involvedObject.name=plain-2
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
kubectl -n kube-system logs -l component=kube-scheduler --tail=5
```{{exec}}

```
"command failed" err="strict decoding error: unknown field \"percentageOfNodeToScore\""
```

The one-liner has a typo: `percentageOfNodeToScore`, with no `s` on `Node`. The scheduler does not ignore a field it does not recognise. It **refuses to start**, and names the field. Nothing is placing Pods while it is down, so a new Pod is `Pending` with no events — the same symptom as every step in this lab, and as a scheduler that was never there.

```plain
sed -i 's/^percentageOfNodeToScore: 100$/percentageOfNodesToScore: 100/' /etc/kubernetes/scheduler-config.yaml
restart-scheduler
configz | grep -o '"percentageOfNodesToScore":[0-9]*'
```{{exec}}

Strict decoding applies to plugin arguments too, and the error says exactly where: a misspelt `resources` under `scoringStrategy` is reported as `unknown field "scoringStrategy.resourcess"`.

</details>
