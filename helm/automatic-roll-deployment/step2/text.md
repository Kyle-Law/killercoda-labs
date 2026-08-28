
Upgrade the release so the message becomes:

```plain
You are overriding the message. Does the pod take this change in consideration?
```

> The chart is at `/charts/mock-app`.

<br>

<details><summary>Tip</summary>

```plain
helm upgrade -h
```{{exec}}

Same technique as the [override-values](https://killercoda.com/helm/scenario/override-values) scenario.

</details>

<details><summary>Solution</summary>

```plain
helm -n dev-ns upgrade mock-app /charts/mock-app --set message="You are overriding the message. Does the pod take this change in consideration?"
```{{exec}}

</details>
