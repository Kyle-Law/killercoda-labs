
<br>

Every other lab in this set uses one Application to manage one thing. This one is about managing a *fleet* of Applications, two different ways.

**App-of-Apps** is the older, simpler idea: an Application is just a Kubernetes object, and Kubernetes objects can generate other Kubernetes objects. Point one Application at a Helm chart (or a plain directory) whose only output is more `Application` manifests, and you get a parent that manages a fixed set of children — add or remove an entry, sync the parent, the set of children changes to match.

**ApplicationSet** solves a different problem: generating Applications from something that isn't a fixed list you maintain by hand — a set of directories in a repo, a set of registered clusters, a set of pull requests. The `applicationset-controller` doing the work is already part of the Argo CD Core install used throughout this `gitops/` set — no extra install needed.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
