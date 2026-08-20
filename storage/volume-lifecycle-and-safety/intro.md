
<br>

Three things about volumes that don't come up until something's already gone wrong:

1. A Pod's writable filesystem belongs to the **container**, not the Pod — a container restart (not a Pod restart) is enough to lose anything you didn't put in a volume.
2. `subPath` lets a `hostPath` volume expose just one subdirectory of the node's filesystem, instead of everything under a shared root.
3. A `hostPath` without that restriction can expose the **entire node filesystem** to a container — a real, commonly-tested security concern, not just a theoretical one.
