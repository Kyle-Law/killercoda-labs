
<br>

### Recap

DRA replaces an opaque counter with an inventory the cluster can actually reason about.

| | Extended resources | DRA |
|---|---|---|
| Node advertises | `nvidia.com/gpu: 4` | `ResourceSlice` describing each device |
| Pod asks for | a number | a claim, optionally filtered by CEL |
| Devices are | interchangeable | distinguishable by attribute |
| Access is | always exclusive | exclusive or shared, by choice |
| "No capacity" vs "no match" | indistinguishable | different, and reported differently |

- **The driver publishes, the scheduler selects.** `ResourceSlice` is the inventory; `DeviceClass` groups it; `ResourceClaim` consumes it.
- **CEL expressions filter on real attributes** — model, memory, index, UUID. Asking for "a GPU with at least 40Gi" is simply not expressible with a counter.
- **Unsatisfiable is not the same as full.** `pod-huge` stayed Pending because nothing *matched*, which the cluster can distinguish from being out of capacity.
- **`ResourceClaimTemplate` gives each Pod its own device; `ResourceClaim` lets Pods share one** — and `status.reservedFor` records exactly who holds it.

### Where this meets the old world

The DRA chart exposes `deviceClass.extendedResourceName` ([KEP-5004](https://github.com/kubernetes/enhancements/issues/5004)), which maps a `DeviceClass` back onto a classic extended resource name. Existing Pods keep writing `resources.limits`, while the devices behind them are managed by a DRA driver — the migration path from one model to the other.

### WELL DONE!

You used the model that replaces the GPU counter, on a cluster with no GPU.
