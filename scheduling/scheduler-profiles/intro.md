
<br>

Every way of changing how the scheduler decides starts in the same place: `KubeSchedulerConfiguration`. A kubeadm scheduler does not read one. It is a static Pod configured by flags, and flags cannot express what you want — several **profiles**, each a named set of plugins and plugin settings, chosen per Pod by `schedulerName`.

This lab moves the scheduler onto a config file, adds a second profile that packs Pods instead of spreading them, and finds the three ways that goes wrong without saying so. In each one the symptom is the one from `scheduler-by-hand`: a Pod that is `Pending` with no events, because nothing is trying to place it.

> The cluster has twelve **fake nodes** (`kubectl get nodes -l type=kwok`) alongside the real one. They are real Node objects the real scheduler places Pods on, and Pods bound to them report `Running` with nothing underneath. Pods that should land on them need `nodeSelector: {type: kwok}` and a toleration; the two Deployments you are given already carry both.

Three helpers are installed, because a broken scheduler is the thing this lab is about:

- `why`{{exec}} — what the last check wanted
- `configz`{{exec}} — the configuration the scheduler is **actually running**, defaults applied. Not the file: what the process loaded. One line of JSON so you can `grep -o` it; `configz -p` pretty-prints
- `restart-scheduler`{{exec}} — restarts the scheduler as a new Pod, and waits for it. It takes under a minute

The kubelet restarts a static Pod when its **manifest** changes. It never looks at the config file the manifest points to, which is why `restart-scheduler` exists. It changes a harmless annotation rather than the usual trick of moving the manifest away and back, because a static Pod's identity is a hash of its manifest: put an unchanged manifest back and you get the same Pod, with the crash back-off it had already built up. Every restart would make the next one slower.

> The scheduler's original manifest is in `/root/kube-scheduler.yaml.orig`. If a step goes wrong enough that it will not come back, `cp` it over `/etc/kubernetes/manifests/kube-scheduler.yaml`.

<br>

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.

Each step is checked with the **CHECK** button. When a check does not pass, run `why`{{exec}} in the terminal — every check in this lab writes down which condition it was not happy with, rather than leaving you to guess.
