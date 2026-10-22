# The Permission You Granted Isn't the One You Need

> **Status:** planned, not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **Topic** | RBAC: subresources (`pods/log`, `pods/exec`, `pods/portforward`), and a diagnostic that lies |
| **CKA domain** | Cluster Architecture, Installation & Configuration (25%): manage role-based access control |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | Ready. No new components. Four claims already observed (below); two to resolve |

## What it teaches

A Role on `pods` reads like it covers everything you can do to a Pod. It covers `get`, `list` and
`watch` of the Pod object. `kubectl logs`, `exec` and `port-forward` are **different resources**
(`pods/log`, `pods/exec`, `pods/portforward`) with their own rules. That much is in every RBAC
tutorial. What is not is that the command people reach for to check it gives the wrong answer.

## The finding at its heart

**`kubectl auth can-i get pods/log` says `yes` when `kubectl logs` is `Forbidden`.** The command takes
`verb resource/resourceName`, so `pods/log` is parsed as *the Pod named `log`*. The form that asks the
real question is `kubectl auth can-i get pods --subresource=log`. The exam's standard RBAC diagnostic
is wrong in exactly the case people test.

## Observed (kind, Kubernetes v1.37.0)

A ServiceAccount bound to a Role granting `get,list,watch` on `pods`, impersonated with `--as`:

| Command | Result |
|---|---|
| `kubectl auth can-i get pods/log` | **yes** (wrong: parsed as a Pod named `log`) |
| `kubectl auth can-i get pods --subresource=log` | no |
| `kubectl logs web` | `cannot get resource "pods/log" in API group "" in the namespace "rb"` |
| `kubectl exec web -- ls` | `cannot create resource "pods/exec" …` |
| `kubectl port-forward web 8080:80` | `error upgrading connection: … cannot create resource "pods/portforward" …` |

After adding `get` on `pods/log` and `create` on `pods/exec`, both worked. Then, with `get` removed from
`pods` (leaving only `list`), `exec` failed with **`cannot get resource "pods"`**: `exec` needs *both*
`get` on the Pod and `create` on `pods/exec`.

## Step outline

1. **The yes that isn't.** `dev` can read Pods. `kubectl logs --as` is `Forbidden`. Run
   `can-i get pods/log` and get `yes`: the contradiction is the lesson. Find the form of `can-i` that
   tells the truth, write it into `/root/answers/step1`, and add the missing rule. Gate: `kubectl logs --as`
   works, and the answer names `--subresource`.
2. **`exec` needs two rules.** Give `dev` the ability to `exec` into Pods in one namespace, and nothing
   else: the check also asserts `dev` still cannot `delete` Pods or read their logs. The trap is a
   Role with only `create` on `pods/exec`, which fails with `cannot get resource "pods"`.
3. **`port-forward`.** Same shape, third subresource, and an error (`error upgrading connection`) that
   does not look like a permission problem at all until the end of the line.
4. **Prove it is the ServiceAccount, not impersonation.** `--as` tests what RBAC says; a real token
   (`kubectl create token`) tests what the API server does with one. Gate: the same three commands
   succeed with the token.

## Must resolve before building

- **What `verbs: ["*"]` on `resources: ["pods"]` covers.** The test was set up and not run. Whether it
  grants `pods/log` and `pods/exec`, and what `pods/*` adds, decides whether a wildcard step is worth
  having. It is the most common over-grant in real clusters.
- **`kubectl create role r --verb=get --resource=pods/log`** builds the right rule on the backend's
  kubectl. Believed yes; the lab's Solutions use it, so confirm it.
- **`--subresource` on the backend's kubectl.** Introduced around 1.24; check the pinned version.
- Whether `kubectl auth can-i --list --as=…` is worth a step: it prints subresources, and may be the
  fastest correct diagnostic.

## Cross-links

- [`troubleshooting/rbac-auth`](../../troubleshooting/rbac-auth/): failures only, and not the
  subresource case. This lab should say so.
- [`ckne/gateway-tls`](../../ckne/gateway-tls/) and friends use `--as` nowhere; this is the first lab
  to teach impersonation, so step 4 should explain what it does and does not prove.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted. See the conventions in `ckne/README.md`.
