
You have a static `index.html` sitting in `/root/site/`. That's the whole starting point.

By the end of this scenario the same file will be a Helm chart that deploys to Kubernetes as a Deployment, is reachable on a NodePort, and renders **which environment it's running in** — so `dev` and `prod` can run side by side from one chart with nothing different but a values file.

The first step deliberately does it the hard way, with `kubectl` only, so you can see what the chart is actually replacing.
