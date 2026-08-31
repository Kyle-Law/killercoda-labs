
`solar-system` is healthy on `v3`, still on manual sync. In the UI, open the app's **DETAILS** panel and find **Sync Policy** — turn on both **Auto-Sync** and, once it's on, **Self Heal**.

Repeat exactly what you did last step: `kubectl set image` straight to `v9`, no Argo CD involved. This time, don't touch the UI at all — just watch. Reload the app in your browser every few seconds instead.

<br>

<details><summary>Tip</summary>

```
kubectl set image deployment/solar-system solar-system=siddharth67/solar-system:v9 -n solar-system
```{{exec}}

Last step, reverting the drift took exactly as long as it took you to notice and click **Sync**. This time there's nothing to click — time how long it actually takes on its own.

</details>

<details><summary>Solution</summary>

```
kubectl get deployment solar-system -n solar-system -o jsonpath='{.spec.template.spec.containers[0].image}'
```{{exec}}

Run that a few times a couple of seconds apart. `v9` shows up briefly, then flips back to `v3` — within a few seconds, with the UI never touched and no `Sync` button pressed by you at all. **Auto-Sync** is what makes Argo CD sync on its own in the first place; **Self Heal** is what makes it react to *this specific kind* of change — a live edit that didn't come through Git — instead of only noticing on its own schedule.

</details>
