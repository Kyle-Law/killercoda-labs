
Bypass Git entirely this time — scale the live Deployment directly with `kubectl`, straight against the cluster, nothing pushed anywhere:

```
kubectl scale deployment solar-system -n solar-system --replicas=5
```{{exec}}

Predict what you'll see before you check. Then check `kubectl get deployment solar-system -n solar-system` a couple of times, a second or two apart.

<br>

<details><summary>Tip</summary>

Compare how long this takes against how long the webhook-triggered sync took last step. Both are "Argo CD noticing something changed" — but one is Argo CD watching *Git* for a new commit, the other is Argo CD watching the *live cluster* for a change to a resource it manages. One of those is a Kubernetes `watch` — a live subscription, always instant — the other needed a webhook because polling Git has no equivalent push mechanism built in.

</details>

<details><summary>Solution</summary>

```
kubectl get deployment solar-system -n solar-system -o jsonpath='{.spec.replicas}{"\n"}'
```{{exec}}

Back to `2` — likely already, by the time you ran the scale command's output finished printing. `selfHeal: true` (set back in step 1) means Argo CD isn't just comparing on a timer; it's watching every resource it manages, and any live change that doesn't match Git gets reverted as fast as the watch event arrives. No webhook needed for this direction — the cluster already tells Argo CD about itself.

</details>
