
The obvious tool is `kubectl diff -k`. Try it:

```plain
kubectl diff -k /root/app; echo "exit=$?"
```{{exec}}

**No differences.** Exit code 0. As far as `diff` is concerned, the cluster matches your configuration perfectly — because `diff` compares the objects *in your config* against their live counterparts. `legacy-flags` isn't in your config, so there is nothing to compare it to.

The same blind spot applies to `kubectl apply --dry-run`, to `kustomize build`, and to reading the repo. Every tool that starts from your configuration is structurally incapable of seeing something your configuration doesn't mention.

To find orphans you have to start from the **cluster** and subtract.

Write the list of ConfigMaps that are in the `demo` namespace but **not** in the render to `/root/orphans.txt`.

<br>

<details><summary>Tip</summary>

```plain
kubectl get configmap -n demo -o name
kubectl kustomize /root/app | grep "name:"
```{{exec}}

`comm` compares two sorted lists and can show you what's only in one of them.

</details>

<details><summary>Solution</summary>

```plain
kubectl get configmap -n demo -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
  | grep -v '^kube-root-ca.crt$' | sort > /tmp/in-cluster.txt

kubectl kustomize /root/app \
  | grep -E "^  name: " | awk '{print $2}' | sort > /tmp/in-config.txt

comm -23 /tmp/in-cluster.txt /tmp/in-config.txt | tee /root/orphans.txt
```{{exec}}

</details>

<br>

<details><summary>Info: why this is harder than it looks in practice</summary>

The comparison above works because the scenario is small and single-kind. In a real cluster you'd have to enumerate **every** kind that could hold an orphan, across every namespace, filtering out objects legitimately created by controllers — ReplicaSets owned by Deployments, Endpoints owned by Services, the `kube-root-ca.crt` ConfigMap injected into every namespace.

That's why the practical answer isn't a script that subtracts lists. It's **labelling everything you own**, so "mine" is a query rather than an inference. That's what the next step sets up.

</details>
