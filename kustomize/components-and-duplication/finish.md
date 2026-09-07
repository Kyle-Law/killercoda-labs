
<br>

### Recap

- **Overlays multiply with optional features.** Environments times features is a directory per combination, and a change to any shared feature becomes a sweep across all of them — with no mechanism to catch the one you miss.
- **A Component is a feature defined once.** Same contents as an overlay, but `kind: Component`, and it is applied *into* whichever overlays list it.
- **Include them under `components:`, not `resources:`.** Getting this wrong is one of the few Kustomize mistakes that fails loudly: `expected kind != 'Component'`.
- **An environment becomes a list of opt-ins.** Prod takes monitoring and HA, staging takes monitoring. Adding a fourth environment is three lines rather than a directory tree.
- **Order decides when components collide, silently.** Two components writing `replicas` produce whichever value comes last. Kustomize does not detect the overlap or warn about it — swapping two lines took the count from 3 to 10.

### The habit

Keep components **disjoint** — each owning fields no other component writes. Where they genuinely must overlap, the `components:` list is load-bearing: comment why the order is what it is, and assert the rendered result rather than trusting the order to survive the next edit.

### WELL DONE!
