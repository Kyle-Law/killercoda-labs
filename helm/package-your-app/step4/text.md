
Now the payoff. Deploy a **second** release of the same chart for production, running alongside `dev`, with nothing different but a values file.

Create `/root/charts/site/values-prod.yaml` and install a release named `prod` such that:

- the page reads `Hello from prod`
- it runs **2** replicas instead of 1
- it's reachable on node port **30081**, while `dev` keeps serving on **30080**

Don't edit `values.yaml` or any template — `dev` must keep working exactly as it is.

<br>

<details><summary>Tip</summary>

A values file only needs the keys it's overriding; everything else falls back to `values.yaml`.

```plain
helm install -h
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
cat > /root/charts/site/values-prod.yaml <<'YAML'
environment: prod
replicaCount: 2
service:
  nodePort: 30081
YAML
```{{exec}}

Preview it before installing:

```plain
helm template prod /root/charts/site -f /root/charts/site/values-prod.yaml | grep -E "Hello from|nodePort:|replicas:"
```{{exec}}

```plain
helm install prod /root/charts/site -f /root/charts/site/values-prod.yaml --wait
```{{exec}}

```plain
helm ls
curl localhost:30080
curl localhost:30081
```{{exec}}

Two releases, one chart, one file of difference.

</details>
