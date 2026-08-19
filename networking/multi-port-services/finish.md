
<br>

### Recap

- A container's named `ports` entries can be referenced from a Service's `targetPort` by name instead of number — handy when the number might change, since the name doesn't have to.
- A Service with more than one port must give every port a unique `name`; the API server rejects an unnamed multi-port Service outright.
- `ExternalName` Services have no selector and no Endpoints at all — they're a pure DNS alias, resolved via a `CNAME` rather than routed through `kube-proxy`.

### WELL DONE!

Combined with the Services & DNS troubleshooting lab, that covers Service routing end to end: selectors, ports by number and by name, multiple ports, and the one Service type that isn't really about routing at all.
