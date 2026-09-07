
<br>

A Kustomize patch has to answer a question YAML can't: when you patch a **list**, which element did you mean?

For some lists Kubernetes publishes a **merge key** — containers merge on `name`, env vars merge on `name`, ports on `containerPort`. Strategic merge uses that key to find your element and merge into it. For other lists there's no key at all, and the whole list is replaced.

And when your key doesn't match anything, strategic merge does not complain. It treats your patch as a **new element** and adds it.

That's the failure this scenario is about: a one-character typo produces a build that succeeds, a manifest that applies, and a Pod that doesn't work — with no warning at any stage.

> A base is at `/root/app/base`: a `web` Deployment with an `app` container (two env vars) and a `logger` sidecar. The overlay at `/root/app/overlay` starts empty.
