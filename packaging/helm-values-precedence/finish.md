
<br>

### Recap

- A values file only needs to contain what you're overriding. `helm get values <release>` shows exactly that — your overrides, not the chart's defaults. Add `-a` to see the full computed tree, defaults included.
- Multiple `-f`/`--values` flags merge left to right — the **rightmost** file wins wherever two files disagree. `--set` wins over **every** `-f`, no matter where it sits on the command line — flag type decides precedence, not position.
- Overrides don't carry forward across upgrades by default — each `helm upgrade` starts from the chart's defaults again unless you add `--reuse-values` (start from the *release's* current values instead) or repeat every `-f`/`--set` you want kept.
- `--set` type-infers bare tokens: `true`/`false` become booleans, plain digit strings become numbers. `--set-string` forces everything to stay a string — the fix for annotations, IDs, or tags that happen to look numeric. `--set-file` loads a file's exact contents as a value, the same trick used for certs or embedded scripts. List elements take index syntax — `--set 'list[0].key=val'` — quoted, because most shells treat unquoted `[` as a glob.
- Merging is deep for maps, but a list is replaced **wholesale** the moment you touch any index in it — the chart's default sibling fields on that element don't survive. Overriding one field of a list element you didn't fully specify yourself means re-specifying the whole element.

### WELL DONE!

None of this changes what a chart *is* — it's still just a template plus a values tree. What changes step to step is which values tree Helm builds before it renders anything, and that's entirely a function of what you pass and in what order.

Most upgrades here succeeded on the first try — the one that didn't (the bare list-index override) failed for a reason worth knowing, not by accident. For what happens — and how to recover — when a failure isn't self-inflicted like that, see `packaging/helm-failed-upgrades`.

This lab assumed you already know `--set` and `-f` exist — for that starting point, see `helm/values-and-overrides`.
