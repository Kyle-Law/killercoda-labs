# The Webhook That Locked You Out

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **Topic** | Cluster administration — admission webhooks and their certificates |
| **CKNE relevance** | None, deliberately. This is control-plane availability, which is why it lives in `cluster-admin/` and not `ckne/`. |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | Ready — no components beyond cert-manager, which is proven on this backend |

## What it teaches

Why cert-manager ships a component whose only job is to write a CA certificate into *other people's
objects*, and what happens when the certificate it manages runs out.

## The finding at its heart

**An admission webhook with `failurePolicy: Fail` and a bad certificate does not degrade — it closes
the door.** Every create and update of every resource it matches is rejected by the API server with a
TLS error, including the resources you would need to touch to fix it.

The blast radius is set by two fields written months apart: which resources the webhook matches, and
what it does when it cannot be reached. Get the first one broad and the second one strict, and a
certificate expiry becomes a cluster-wide outage with a confusing symptom — `kubectl apply` failing
on objects that have nothing to do with certificates.

## Step outline

1. **The bootstrapping problem, stated.** An API server will not call a webhook it cannot verify, so
   the webhook's `caBundle` has to be populated before the webhook can ever run. Meet `cainjector`
   and the `cert-manager.io/inject-ca-from` annotation, and watch the field get filled in by a
   controller rather than by hand.
2. **Break it and feel it.** Invalidate the webhook's certificate. Then try ordinary, unrelated work
   and watch it fail — the symptom arrives nowhere near the cause, and the error text is the only
   thread back.
3. **Get out.** Recover, and rank the escape routes honestly: fix the certificate, narrow the
   webhook's scope, or delete the webhook configuration outright. Establish which of those still work
   *while you are locked out* — that is the whole skill.
4. **Design so it cannot happen.** `failurePolicy: Ignore` versus `Fail` as a real availability-versus-
   enforcement trade, narrow `rules` and `namespaceSelector` as blast-radius control, and the
   specific trap of a webhook broad enough to intercept the objects its own issuer needs.

## Must resolve before building

- **How to invalidate the certificate reproducibly and reversibly.** Waiting for a real expiry is out.
  Replacing the Secret's contents, or issuing from a different CA than the `caBundle` names, should
  both produce the same verification failure — pick whichever recovers cleanly, and make certain the
  lab cannot wedge itself somewhere `kubectl` cannot reach.
- **That step 2's failure stays inside the lab's own webhook.** The scenario must break a webhook
  created for the lab, never cert-manager's own admission webhook — a learner who wedges that has no
  route back and the scenario is unrecoverable.
- The exact API server error text at the pinned Kubernetes version. Step 2's whole value is that the
  learner recognises it later, so it must be quoted, not paraphrased.
- Whether a `verify.sh` can confirm recovery without itself being blocked by the broken webhook.

## Cross-links

- [`cert-manager/certificate-renewal`](../../cert-manager/certificate-renewal/) — the same expiry with
  a smaller blast radius, and the lab that explains why renewal is not automatic for every consumer.
- [`cert-manager/issuers-and-trust`](../../cert-manager/issuers-and-trust/) — where the CA in step 1
  comes from.
- [`cluster-admin/kubeadm-maintenance`](../kubeadm-maintenance/) — the other lab in this folder about
  a control plane you have to get back.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted — see the conventions in `ckne/README.md`.
