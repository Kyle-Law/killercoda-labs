# Triaging a Broken Pod-to-Pod Path

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Core Infrastructure & CNI (15%) |
| **Exam objective** | Troubleshooting Pod Connectivity (DNS, pod-to-pod) |
| **Proposed backend** | `kubernetes-kubeadm-2nodes` |
| **Feasibility** | Ready |

## What it teaches

An order of elimination for 'it can't reach it': namespace, then interface, then route, then policy, then DNS — checking the cheap and decisive things before the expensive and ambiguous ones.

## Step outline

1. A broken path is presented with no diagnosis. Establish first whether it is name resolution or connectivity at all — the two produce different errors.
2. Work down the stack: is the Pod's interface up, does it have a route, does the peer answer on its Pod IP?
3. Rule policy in or out deliberately rather than by deletion.
4. Same symptom, a second, different root cause — proving the method rather than the answer.

## Must resolve before building

- That failures can be injected reproducibly on the backend (a bad route, a dropped interface) without wedging the node.

## Cross-links

- Builds on `packet-path-with-linux-tools`.
- Complements `troubleshooting/services-dns`.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down.
