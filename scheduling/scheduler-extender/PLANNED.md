# Customise the Scheduler over HTTP

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **Topic** | Scheduler extenders: `filter` and `prioritize` webhooks, and their failure semantics |
| **CKA relevance** | Beyond CKA. Useful anywhere placement depends on something only an external system knows |
| **Proposed backend** | `kubernetes-kubeadm-1node` + KWOK; the extender runs as `python3` on the host |
| **Feasibility** | Blocked on the KWOK spike. No third-party images. One message to capture |

## What it teaches

Profiles reconfigure plugins that already exist. An extender adds a decision the scheduler can't make
on its own, with no Go, no rebuild and no image: the scheduler POSTs the Pod and the candidate nodes to
a URL and acts on the answer. It's the scheduler's equivalent of an admission webhook, and it has the
same choice to make when the webhook is down.

The extender runs as a Python process on the control-plane host at `127.0.0.1`. The scheduler is a
`hostNetwork` static Pod, so it needs no Service, no DNS and no TLS. The learner edits one Python file.

## The finding at its heart

**`ignorable` decides which outage you get.** With `ignorable: false`, the default, a dead extender
stops scheduling for every Pod it applies to, and with empty `managedResources` that is *every Pod in
the cluster*. With `ignorable: true`, Pods schedule normally and your policy is silently not enforced.
The only trace is an `Info`-level line in the scheduler's log: *"Skipping extender as it returned error
and has ignorable flag set"*. That's the same choice as an admission webhook's `failurePolicy`, made in
a file most people never open.

## Step outline

1. **A filter.** Placement depends on an external fact the cluster doesn't have: a power budget per
   rack, read from a JSON file the extender loads. Pods declare their wattage in an annotation. The
   extender's `filter` verb drops nodes that would go over budget. Wire it into the config from
   [`scheduler-profiles`](../scheduler-profiles/) with `nodeCacheCapable: true`. Gate: a Pod lands only
   on nodes with headroom, and `FailedScheduling` shows the extender's own reason when none fits.
2. **A score.** Add a `prioritize` verb returning 0–10 per node with `weight: 2`. Using the `V(10)`
   score logs from [`filter-and-score`](../filter-and-score/), confirm the scheduler multiplies by 10
   to put extender scores on the plugins' 0–100 scale. Then predict a final score by hand.
3. **Kill it.** Stop the Python process and create a Pod: `Pending`, and so is every other new Pod in
   the cluster. Set `ignorable: true` and restart the scheduler: Pods schedule, and over-budget nodes
   get used. Find the one log line that recorded it. Gate: the learner records which mode they would
   run in production, and what alert it needs.
4. **Narrow the blast radius.** Set `managedResources` to an extended resource,
   `example.com/watts`, so only Pods that request it are sent to the extender. Everything else
   bypasses it, dead or alive. Gate: with the extender stopped and `ignorable: false`, an ordinary Pod
   schedules and a watt-requesting Pod does not.

## Must resolve before building

- **The `FailedScheduling` message when a non-ignorable extender is unreachable.** It's an error status
  rather than unschedulable, which may put the Pod in backoff rather than the unschedulable queue, and
  may word the event differently. Quote it.
- **Whether extenders are still supported at the pinned version**, with no deprecation warning at
  startup. They are present in `master` as of October 2026. Check the release notes for the backend's
  version.
- How `managedResources` interacts with `ignoredByScheduler: true`. If the scheduler ignores a resource
  that no node advertises, it shouldn't need fake capacity on every node. Confirm it, and if it
  doesn't work, the init advertises the resource on the fake nodes instead.
- The JSON shape the scheduler sends with `nodeCacheCapable: true` (node names only) versus `false`
  (full Node objects), so the starter Python file parses the right one.

## Cross-links

- Config file and static Pod manifest from [`scheduler-profiles`](../scheduler-profiles/).
- Score arithmetic from [`filter-and-score`](../filter-and-score/).
- [`cluster-admin/webhook-certificate-expiry`](../../cluster-admin/webhook-certificate-expiry/) is the
  same fail-open versus fail-closed choice, on the admission side.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted. See the conventions in `ckne/README.md`.
