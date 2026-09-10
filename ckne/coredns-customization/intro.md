
<br>

`troubleshooting/services-dns` covers cluster DNS when it breaks. This covers the part before that: the Corefile is an ordinary configuration file, and most people never open it.

Which is a shame, because almost everything teams want from cluster DNS is a few lines in it. Reaching a corporate resolver that owns a zone Kubernetes has never heard of. Keeping an old hostname working after the service behind it moved. Finding out which queries are actually being made, and by whom. None of that needs a sidecar, a mesh, or an application change.

It also has two properties worth knowing before you touch it in production. The order plugins appear in the file is **not** the order they run in. And a Corefile with a typo in it does not take DNS down — it does something quieter and considerably worse.

Three things are running: `web` with a Service, a `dnstools` Pod to ask questions from, and — in the `corp-dns` namespace — a completely separate DNS server that is authoritative for `corp.internal` and knows nothing about this cluster. Treat it as the resolver another team runs.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
