
<br>

Every other lab in this repo treats `kube-scheduler` as the thing that places Pods. This one shows it is only *a* thing that places Pods.

The scheduler is an ordinary API client. It watches for Pods that have no node, picks one, and writes a single field. **Anything else that writes that field schedules the Pod just as well — and the scheduler's rules are only enforced if whatever is doing the writing chooses to enforce them.**

So you will be the scheduler. Once by hand, then as a loop of sixteen lines of bash. Then you will find out which rules you never wrote, who — if anyone — enforces them after you, and what happens to a Pod that the next component down refuses.

> The cluster has two nodes. The worker's name is in `/root/worker`.

<br>

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.

Each step is checked with the **CHECK** button. When a check does not pass, run `why`{{exec}} in the terminal — every check in this lab writes down which condition it was not happy with, rather than leaving you to guess.
