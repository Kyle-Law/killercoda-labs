
Upgrade the `mock-app` release so its message becomes:

```plain
You are overriding the message using an inline value. Good job!
```

Use the **inline** method (`--set`) rather than a values file.

> The chart is at `/charts/mock-app`.

<br>

<details><summary>Tip</summary>

```plain
helm upgrade -h
```{{exec}}

The value you need is called `message` — confirm with `helm get values --all mock-app -n dev-ns`.

</details>

<details><summary>Solution</summary>

```plain
helm -n dev-ns upgrade mock-app /charts/mock-app --set message="You are overriding the message using an inline value. Good job!"
```{{exec}}

```plain
helm get values mock-app -n dev-ns
```{{exec}}

</details>
