
Now do the same thing the way you'd actually do it in production — with a values file, so the configuration can live in Git and be reviewed.

Create `/charts/values.yaml` setting the message to:

```plain
You are overriding the message using a values file. You rock it!
```

Then upgrade the release using that file instead of `--set`.

<br>

<details><summary>Tip</summary>

```plain
helm upgrade -h
```{{exec}}

The flag is `-f` / `--values`, and it can be given more than once — later files win.

</details>

<details><summary>Solution</summary>

```plain
echo 'message: You are overriding the message using a values file. You rock it!' > /charts/values.yaml
cat /charts/values.yaml
```{{exec}}

```plain
helm -n dev-ns upgrade mock-app /charts/mock-app --values /charts/values.yaml
```{{exec}}

```plain
helm get values mock-app -n dev-ns
```{{exec}}

</details>
