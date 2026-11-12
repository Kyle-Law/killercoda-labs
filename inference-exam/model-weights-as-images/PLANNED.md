# Model Weights as an Image

> **Status:** planned, not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **Topic** | Image volumes (`volumes[].image`): shipping model weights as an OCI image, and how they fail |
| **Domain** | Model server lifecycle and delivery (15%) |
| **Proposed backend** | `kubernetes-kubeadm-1node`; the weights images are assembled in the init (see *Must resolve*) |
| **Feasibility** | Steps 1-3 **ready** on kind (observed below). Step 4 unobserved. The backend's runtime unchecked |

## What it teaches

A model server's image is the engine; the weights are gigabytes that change on a different schedule.
The usual ways to get them in, an init container that downloads on every start or a PVC someone has
to fill, both put a moving part between the Pod and readiness. An image volume mounts an OCI image's
filesystem read-only into the Pod, pulled and cached by the node like any image, versioned by tag or
digest like any image.

It also fails like an image, which is where it gets confusing, because it is not the container's image.

## The finding at its heart

**A wrong weights reference shows as `ImagePullBackOff` on a container whose own image is fine.** The
Pod's status column, the container state and the events all say image pull; the learner checks the
container's `image:` and finds nothing wrong. Only the message names the volume's reference.

The second: **`subPath` into an image volume works for a directory and refuses a file.** One image can
carry several models and each Pod mounts its own directory. Mounting a single file from it fails with
`only directory subpath is supported`.

## Observed (kind, Kubernetes v1.37.0, containerd 2.3.4)

Weights image: `FROM scratch`, a 50 MB `model.safetensors` and a `config.json`. Reader: `busybox`.
No feature gate was set.

| Case | Result |
|---|---|
| `image: {reference: local/demo-weights:v1, pullPolicy: IfNotPresent}` at `/models` | Ready. Both files present; `touch /models/x` → `Read-only file system` |
| reference `local/demo-weights:v9` (does not exist) | `ImagePullBackOff`. Container state: `Back-off pulling image "local/demo-weights:v9": ErrImagePull: failed to pull and unpack image "docker.io/local/demo-weights:v9" …`. The container's own image, `busybox:latest`, was present |
| `subPath: config.json` (a file) | never Ready. Event: `Error: failed to mount image volume: ImageVolumeMountFailed: failed to ensure image subpath "config.json" in "/run/containerd/…": only directory subpath is supported` |
| image with `/model-a` and `/model-b`, `subPath: model-b` at `/models` | Ready; `/models/config.json` is model-b's |

## Step outline

1. **Weights that arrive like an image.** Mount the weights image into a Deployment; prove the files
   are there and read-only. Gate: Pod Ready and `/models/config.json` readable from it.
2. **The pull that is not the container's.** A "v2 rollout" sits in `ImagePullBackOff`. The container
   image is unchanged and fine; find which reference is failing and fix it. Gate: the rollout
   completes on a weights reference that exists.
3. **One image, two models.** Mount only `model-b` from the multi-model image. The file `subPath` a
   learner tries first fails; the directory works. Gate: the Pod reads model-b's config and not
   model-a's.
4. **New weights, same tag.** Re-push the tag with new weights; a new Pod on the same node still gets
   the old ones under `IfNotPresent`. Pin by digest. Gate: the Deployment's reference contains `@sha256:`.
   *Unobserved:* see below.

## Must resolve before building

- **The backend's container runtime.** Image volumes need runtime support. Observed on containerd
  2.3.4; check the backend's version first, since an unsupported runtime makes the whole lab moot.
- **Getting a data-only image onto the backend.** The kubeadm backend has containerd, not Docker.
  Options: hand-assemble an OCI layout tarball in the init (tar, `sha256sum`, two JSON files) and
  `ctr -n k8s.io images import` it, or run a registry Pod in the cluster and push to it. Step 4 needs
  the registry either way.
- **Step 4 is unobserved.** The attempt stalled pulling `registry:2` from Docker Hub during the spike.
  Run it with a registry before writing the step, and confirm the stale-content behaviour rather than
  assuming it from container images.
- **The Pod's status in the file-`subPath` case.** Only the event was captured; record what the
  `STATUS` column shows.
- **Cold start.** The claim that a second Pod on the same node starts faster than with an init-container
  download is plausible and was not timed. Either measure it with a realistic size or leave it out.

## Cross-links

- [`troubleshooting/pod-failures`](../../troubleshooting/pod-failures/) step 2: the ordinary
  `ImagePullBackOff`, where the container's image really is the problem.
- [`storage/volumes-basics`](../../storage/volumes-basics/): the other volume types.
- [`probes/restart-remove-or-wait`](../../probes/restart-remove-or-wait/): the slow model load that
  `startupProbe` exists for, which image volumes shorten but do not remove.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted. See the conventions in `ckne/README.md`.
