
<br>

Based on *Learn Kubernetes in a Month of Lunches*, Day 7 — "Extending applications with multicontainer Pods."

A Pod is a shared network and filesystem environment for one or more containers: they get the same IP address and can talk over `localhost`, and they can mount the same volumes — with independent access levels per mount. This lab covers three patterns that build on that: sharing a volume read-write/read-only, init containers that must finish before app containers start, and the sidecar pattern for bringing an old app's file-based logging in line with how Kubernetes expects logs to work.
