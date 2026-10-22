# Four Faults, Thirty Minutes

> **Status:** planned, not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **Topic** | Triage order across domains: one broken two-node cluster, four unrelated faults |
| **CKA domain** | Troubleshooting (30%), touching Cluster Architecture, Services and Workloads |
| **Proposed backend** | `kubernetes-kubeadm-2nodes` |
| **Feasibility** | Assembly. Two faults are proven elsewhere in this repo, one is observed in `cka/`, one needs verifying |

## What it teaches

Every other lab here has one fault and says so. The exam has several, unlabelled, with a clock. The
skill is the *order*: which fault hides the others, which is quickest, and when to stop digging.

## The finding at its heart

**Fix the scheduler first, because it is hiding two of the other faults.** With a dead scheduler no new
Pod gets a node, so a broken Service backend and a broken volume claim cannot even be *reached*: both need
a running Pod to show their symptoms. The learner who starts with the Service finds nothing to look at.

## The faults

| | Fault | Visible symptom | Proven in |
|---|---|---|---|
| A | The scheduler's manifest passes `--config` for a file the container cannot see | every new Pod `Pending`, no events | [`scheduling/scheduler-profiles`](../../scheduling/scheduler-profiles/) step 1 |
| B | A ServiceAccount can `get pods` but not `logs` | `Forbidden … cannot get resource "pods/log"` | [`rbac-subresources`](../rbac-subresources/) |
| C | A Service whose selector matches nothing | `Endpoints: <none>`, requests refused | `troubleshooting/services-dns` |
| D | A PVC naming a StorageClass that does not exist | Pod `Pending`, claim `Pending` | **not yet verified** |

C and D need a running Pod to show their symptoms, so they stay invisible until A is fixed.

## Shape

One step, one checklist. Killercoda enforces step order and the exam does not, so the lab is a single
step whose check prints four lines (fixed, or still wrong and why) and passes only when all four are
fixed. The init writes the start time to `/root/.start`, and the check prints the elapsed minutes against
a 30-minute target, so the learner can see a pace without being failed for it.

## Must resolve before building

- **Fault D's real symptoms.** What a PVC with a missing StorageClass says, on the backend, and whether
  the Pod and the claim report it in the same words.
- **That the init can break the scheduler without breaking its own checks.** Every check creates Pods,
  and a dead scheduler leaves them `Pending`: a check that passes by accident, or one that cannot pass,
  are both live risks. The checks should reason from object state where they can.
- **Whether the other labs' fault injections survive being combined.** A shared `kubectl` context and
  one `~/.kube/config` is the plan; confirm none of the four breaks it.
- **Realism of 30 minutes** for four faults on this backend. Time a cold run before publishing a number.
- Whether a fifth, masked fault (one that appears only after C is fixed) is worth the added length.

## Cross-links

- Each fault's own lab teaches the diagnosis; this one tests the *sequencing* and says so in its intro.
- [`troubleshooting/control-plane`](../../troubleshooting/control-plane/): the static-Pod technique fault
  A needs, in its simplest form.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted. See the conventions in `ckne/README.md`.
