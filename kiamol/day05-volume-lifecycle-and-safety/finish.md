
<br>

### Recap

- "Pod restart" almost always means a **container** got replaced — the writable filesystem has the container's lifecycle, not the Pod's. Anything that must survive belongs in a volume.
- `subPath` narrows a volume mount down to one subdirectory, without needing a separate `hostPath` entry per directory.
- An unrestricted `hostPath` on `/` hands a container root-equivalent access to the entire node — treat it the same as any other privilege-escalation risk, not just a storage choice.

### WELL DONE!

Same fix pattern both times: scope the mount with `subPath` rather than trusting the container to behave.
