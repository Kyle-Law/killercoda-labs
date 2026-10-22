# One ConfigMap, Three Behaviours

> **Status:** planned, not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **Topic** | How a ConfigMap change reaches a running Pod: volume, environment variable, `subPath` |
| **CKA domain** | Workloads & Scheduling (15%): configure workloads with ConfigMaps and Secrets |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | Ready. No new components. The core behaviour is observed (below); two claims to resolve |

## What it teaches

Update a ConfigMap and ask which of your Pods noticed. The answer depends on *how each one consumes
it*, and the three common ways give three different answers from the same object.

## The finding at its heart

**Of three ways to consume one ConfigMap, only the volume ever updates, and only after about a minute.**
The environment variable and the `subPath` mount never change for the life of the Pod. `subPath` is the
one that surprises people, because it *is* a volume mount and looks like the one that works.

## Observed (kind, Kubernetes v1.37.0)

One Pod consuming ConfigMap `app` (`color=blue`) three ways, then the ConfigMap changed to `green`:

| After | `env` | whole-directory volume | `subPath` file |
|---|---|---|---|
| change + 32s | blue | blue | blue |
| change + 65s | blue | blue | blue |
| change + about 89s | blue | **green** | blue |
| change + 90s, final | blue | green | blue |
| a **new** Pod | green | n/a | green |

The volume changed between 65 and 89 seconds, polled at 8-second intervals.

## Step outline

1. **Predict, then watch.** Apply the Pod from the init, change the ConfigMap, and write what each of
   the three consumers will show into `/root/answers/step1` as `env=<yes|no> volume=<yes|no>
   subpath=<yes|no>`. Gate: the answer matches what the Pod actually shows two minutes later, read by
   the check. Also record how long the volume took.
2. **Make the change arrive without a restart.** The app reads `/single/color` and its owner will not
   restart it. Convert the `subPath` mount into a directory mount (and the app's path with it). Gate: a
   new ConfigMap value appears in the running Pod within two minutes.
3. **The ConfigMap you cannot edit.** `immutable: true`. The update is rejected, so roll the change by
   *name*: create `app-v2`, point the Deployment at it, and let the rollout replace the Pods. Gate: the
   Deployment's Pods all read the new value and `app` is untouched.
4. **Why that is the better design.** Immutable plus a new name makes a config change a rolling update,
   which is the same mechanism `kustomize`'s generated-name hash uses. A short step linking the two.

## Must resolve before building

- **The exact error for editing an immutable ConfigMap.** Not captured; step 3's text quotes it.
- **The timing variance.** One run gave about 89 seconds. Kubelet sync period plus cache TTL is the
  expected cause; run it five times and quote a range, because the check's two-minute window sits close
  to it.
- **Whether a Secret volume behaves the same.** Expected yes. It decides whether the lab can say
  "ConfigMaps and Secrets" in the recap.
- Whether `envFrom` behaves like `valueFrom` (expected: no update).
- Step 2's check must wait for the kubelet's sync, so it needs a retry loop of about 150 seconds. See
  the check conventions about reporting which condition it is still waiting on.

## Cross-links

- [`kustomize/overlays-and-generated-config`](../../kustomize/overlays-and-generated-config/): the
  generator's name hash, which is step 3's technique done by a tool.
- [`kiamol/day10-helm`](../../kiamol/day10-helm/) and the Helm labs: a `checksum/config` annotation
  is the other standard answer to "the Pod never noticed".

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted. See the conventions in `ckne/README.md`.
