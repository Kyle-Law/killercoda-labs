
<br>

`kubectl apply` is a one-way instruction: *make these objects look like this*. It says nothing about objects you didn't mention.

So when you delete a resource from a kustomization and re-apply, the object stays in the cluster. It is no longer described anywhere in your repository, nothing manages it, and nothing will tell you it exists. It just keeps running — holding a name, consuming quota, and occasionally still being read by something.

That's how clusters accumulate resources nobody can account for: not through carelessness, but because the tool that created them has no mechanism for noticing their absence.

This scenario creates that situation deliberately, shows why the obvious detection tools miss it, and then uses `--prune` — which solves it by introducing a different and considerably sharper hazard.

> `/root/app` has a kustomization with three ConfigMaps, targeting the `demo` namespace.
