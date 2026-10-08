
<br>

### Recap

**`FailedScheduling` reports one reason per node, and the order is the filter order.** Taints, then node affinity and selectors, then resources. A node that fails for several reasons says only the first, so the message is a histogram of first failures: 13 nodes failing four different ways read `2 Insufficient cpu, 3 … didn't match … selector, 8 … untolerated taint(s)`, and tolerating the taint turned it into `5 Insufficient cpu, 8 … didn't match … selector`. The eight tainted nodes had been hiding five cpu failures and three selector ones. **Fix what the message says, and read it again: the next one was always there.** The `preemption:` half asks a second question of the same nodes, whether evicting something would help. For a taint or a selector it cannot (*Preemption is not helpful*); for a full node it could, but nothing of lower priority is there (*No preemption victims found*).

**The scheduler scores what survives the filters, and logs every plugin's score if you ask** (`--vmodule=schedule_one=10`, for one source file). **The logged scores are already multiplied by the plugin's weight**: `TaintToleration` logs 300 for a clean node, which is 100 × 3, and the plugin lines sum to the total. Only plugins with something to say vote: a Pod with no affinity and no workload is scored by six, not eight.

**A preference is a vote, not a wish, and it has a price.** A preferred affinity is worth **200** to the node that matches it best: the scheduler scales that node to 100 whatever the term's weight (`weight: 1` scored the same as `weight: 100`, and a weight only matters against *other* preferred terms), and `NodeAffinity` has a plugin weight of 2. One untolerated `PreferNoSchedule` taint costs **300**, because `TaintToleration` has a weight of 3. Six replicas preferring one node: 6 of 6 reached it, **0 of 6** once it carried a soft taint they did not tolerate, and 6 of 6 again once they did. The most a preference can be worth is less than a soft taint takes away, and raising its weight does not change that.

**A preference also wears out.** At a dozen nodes with nothing in the way, 18 of 20 replicas reach the preferred node, not 20: as the node fills, the built-in default spreading (`PodTopologySpread`, applied to a Deployment's Pods, whether or not anyone wrote a constraint) scores it lower and lower, from 200 to 14, until the total is 671 against 672 and the next replica goes elsewhere.

**Above 100 nodes the scheduler stops looking.** It stops filtering as soon as it has found `50 − nodes/125` percent of them feasible (never below 5%, never below 100 nodes): **120** of 251, **230** of 501. It scores only those, starting each search where the last ended, so a node that is the unambiguous best is in the window about half the time. The same 20 replicas that put 18 on the preferred node at a dozen put **6 to 11** on it at 251, varying from run to run. The line that says so is `Successfully bound pod to node … feasibleNodes=120`, and it is `V(2)`: absent at default verbosity. `percentageOfNodesToScore: 100` made it 250, and the count **16 every time**. The cost is real, since scoring is the expensive half, which is why it is not the default.

**A node that reports `Ready` is not yet a candidate.** New nodes carry `node.kubernetes.io/not-ready:NoSchedule` until the node lifecycle controller removes it, about five a second. 250 nodes take a minute, 500 about two, and any experiment that counts nodes before then is counting a smaller cluster.

### WELL DONE!

You can now read why a Pod fits nowhere without being fooled by what the message leaves out, read the scheduler's arithmetic when it does place one, and say how far the scheduler looked.

## Where to go next

- [`scheduling/scheduler-profiles`](../scheduler-profiles/) — the config file you edited in step 4, and how to give a profile different weights and settings
- [`scheduling/topology-spread`](../topology-spread/) — the default spreading that wore the preference out, written on purpose *(planned)*
- [`workloads/scheduling-constraints`](../../workloads/scheduling-constraints/) — where the single-reason version of step 1 starts

> See [`scheduling/README.md`](../README.md) for how this lab relates to the rest of the set.
