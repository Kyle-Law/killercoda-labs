
<br>

Helm is explicit CKA content — "use Helm and Kustomize to install cluster components" sits under Cluster Architecture. This lab covers the repo workflow with a version pin, values overrides, release history and rollback (the Helm counterpart to `kubectl rollout`), and building a chart from nothing.

`helm` isn't installed by default here, so the first step installs it. On the real exam it's already there — installing it isn't the skill being tested, just something this lab has to do for itself first.

This lab avoids Bitnami's chart repo (its public catalog was disrupted in 2025) in favor of [podinfo](https://github.com/stefanprodan/podinfo), a small, stable chart maintained specifically for demos like this one.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
