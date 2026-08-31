
`solar-system` is `Synced`/`Healthy` on `v3` again. From the terminal — not the UI — bump it straight to `v9`, bypassing Argo CD entirely:

```
kubectl set image deployment/solar-system solar-system=siddharth67/solar-system:v9 -n solar-system
```{{exec}}

Reload the app in your browser tab — it should look different. Now switch back to the Argo CD UI. The app card shows `OutOfSync`. Before clicking anything, predict what pressing **SYNC** does: does it accept `v9` as the new normal, or does it do something else? Then click it, and check the app in your browser again.

<br>

<details><summary>Tip</summary>

`Sync` only ever has one direction: cluster state moves toward what's in Git. `v9` was never written to Git — you only ever changed the live Deployment. Whatever "the correct state" means to Argo CD, it isn't "whatever's currently running."

</details>

<details><summary>Solution</summary>

After clicking **SYNC** in the UI, reload the app:

[VIEW THE APP]({{TRAFFIC_HOST1_30090}})

Back to `v3`. `Sync` reverted your manual change instead of adopting it — confirm from the terminal:

```
kubectl get deployment solar-system -n solar-system -o jsonpath='{.spec.template.spec.containers[0].image}'
```{{exec}}

`v9` never had a chance of sticking: Argo CD doesn't ask "is the cluster in a good state," it asks "does the cluster match Git" — and Git still said `v3` the entire time.

</details>
