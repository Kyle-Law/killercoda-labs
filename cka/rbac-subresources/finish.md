## What you found

A Role on `pods` is a Role on the Pod **object**. Everything `kubectl` does that streams, or reads something other than the object, is a subresource with its own rule.

| You run | RBAC wants |
|---|---|
| `kubectl logs` | `get` on `pods/log` |
| `kubectl exec` | `create` on `pods/exec`, **and** `get` on `pods` |
| `kubectl port-forward` | `create` on `pods/portforward`, **and** `get` on `pods` |

**The diagnostic that says yes.** `kubectl auth can-i get pods/log` reads `pods/log` as *`verb resource/resourceName`*: the Pod named `log`. If you can `get` Pods, you can `get` that one, and it says `yes` while `kubectl logs` is Forbidden. `--subresource=log` is the form that asks the real question. `auth can-i --list` shows the same fact from the other side: a `pods` row, and no row for any subresource.

**The error that does not look like RBAC.** A refused `port-forward` opens with `error upgrading connection: unable to upgrade connection`, and a refused `exec` can open with `unable to upgrade connection`. It reads like a network fault. The sentence that matters is at the far end of the line.

**Exec needs two rules.** With only `create` on `pods/exec`, the refusal names `get` on `pods`. The error for the missing rule does not mention `exec`, so it reads as an unrelated problem.

**A wildcard that is not one.** `pods/*` is accepted, listed by `can-i --list`, and matches nothing. The wildcards RBAC understands are `*` and `*/log`-style, never `pods/*`. Separately, `verbs: ["*"]` on `pods` includes `delete` and excludes `pods/log` and `pods/exec`: the wildcard stops at the slash.

**A test that tested the admin.** `kubectl --token=…` against a kubeadm kubeconfig is authenticated by the client certificate; the token is never consulted. `exec` succeeded, which should have been the warning. `kubectl auth whoami` says who the API server thinks you are, and it is the first thing to run when a result surprises you.

## The shape of it

> Each of these gave an answer. The answer was well-formed, confident, and about a different question from the one asked.

`can-i` answered about a Pod called `log`. `--list` showed a rule that matched nothing. `--token` answered as someone else. None of them failed; they succeeded at the wrong thing. When a permission check and the command disagree, one of them is not asking what you think, and the command is the one that is right.

## Where to go next

- **[`troubleshooting/rbac-auth`](https://killercoda.com/kylelaw/course/troubleshooting/rbac-auth)** — the other half: a missing binding, a Role that does not grant enough, and a binding with the wrong scope. None of them involve a subresource, and `can-i` without the trap is the diagnostic there.
- `kubectl auth can-i --list` on any ServiceAccount you inherit, before reading its Roles.

> **Versions.** Run on Kubernetes v1.37.
