
<br>

### Recap

**Adding `--config` quietly disables the `--kubeconfig` flag on the line above it.** The flag reference lists six that stop meaning anything the moment a config file is named: `--kubeconfig`, `--kube-api-qps`, `--kube-api-burst`, `--kube-api-content-type`, `--profiling` and `--contention-profiling`. The manifest still shows them. The scheduler's own message is the part that misleads: with `--kubeconfig=/etc/kubernetes/scheduler.conf` on its command line, it logs *Neither --kubeconfig nor --master was specified*. And before that failure there is an earlier one that points elsewhere: a static Pod sees only what its manifest mounts, so a file that is plainly on the host is `no such file or directory` in the container.

**The kubelet restarts a static Pod when its manifest changes, and never when the config file it points to changes.** Edit only the file and nothing happens. The usual fix, moving the manifest away and back, returns the same Pod: its identity is a hash of the manifest (`kubernetes.io/config.hash` on the mirror Pod stayed identical across the round trip and changed with an annotation), so it also returns the crash back-off the earlier attempts had built up. A restart that follows a few crashes can take minutes, and each one lengthens the next. `/configz` is the scheduler's running configuration with defaults applied, which is how you tell what it *loaded* from what you *wrote*.

**A profile that does not pack was outvoted by a default nobody wrote.** `MostAllocated` earned an occupied node about 4 extra points on `NodeResourcesFit` (11 against 7); `PodTopologySpread`, applying built-in spreading constraints to a Deployment's Pods, scored the same node 28 to 54 points lower. Twelve replicas still used twelve nodes. `defaultingType: List` with an empty `defaultConstraints` switches the built-ins off for that profile only, and the twelve went to one node. The score log (`--vmodule=schedule_one=10`) is the only place this was visible.

**`profiles` is the whole list, not a list of additions.** A config naming only `bin-packing` starts cleanly, passes health checks, serves `/configz`, and leaves every Pod that does not name a scheduler without anyone to place it: `Pending`, no events, no `PodScheduled` condition, nothing in the log. It is the `scheduler-by-hand` symptom reached by an ordinary-looking config change.

**The scheduler refuses what it does not recognise.** Verified on v1.37.0 with the exact errors:

| What you wrote | What the scheduler said |
|---|---|
| `percentageOfNodeToScore: 100` | `strict decoding error: unknown field "percentageOfNodeToScore"` |
| `resourcess:` under `scoringStrategy` | `strict decoding error: decoding args for plugin NodeResourcesFit: strict decoding error: unknown field "scoringStrategy.resourcess"` |
| a profile with no `queueSort` plugin | `only one queue sort plugin required for profile with scheduler name "bin-packing", but got 0` |
| two profiles, one name | `profiles[1].schedulerName: Duplicate value: {}` |
| a profile with no name | `profiles[1].schedulerName: Required value` |

Each one is a crash, and a crashed scheduler is, from every Pod's point of view, the same as no scheduler.

### WELL DONE!

You can now move a kubeadm scheduler onto a config file, give it a second personality, and tell the difference between a profile that does not work and a profile that is being outvoted.

## Where to go next

- [`scheduling/filter-and-score`](../filter-and-score/) — the score log you used in step 2, for every plugin at once, and why `feasibleNodes` stops at 230 on a 500-node cluster *(planned)*
- [`scheduling/scheduler-by-hand`](../scheduler-by-hand/) — the symptom this lab keeps producing: a Pod nothing is trying to place
- [`scheduling/scheduler-extender`](../scheduler-extender/) — adds an `extenders:` list to this same file *(planned)*

> See [`scheduling/README.md`](../README.md) for how this lab relates to the rest of the set.
