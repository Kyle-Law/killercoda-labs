
<br>

`ckne/gateway-tls` used `cert-manager`, but it used it the way most tutorials do: a working `ClusterIssuer` arrives pre-built, you write a `Certificate`, a Secret appears. The only field that mattered was `secretName`.

This lab is the layer underneath that. Where does an issuer live, whose Secret does it read, and what does it look like when it reads the wrong one — which, in `cert-manager`, is almost never an error you get back from `kubectl apply`.

`cert-manager` and `trust-manager` are installed. There are three namespaces — `pki`, `app` and `client` — and one `Certificate` that has been sitting there failing to issue since before you arrived.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.

Each step is checked with the **CHECK** button. When a check does not pass, run `why`{{exec}} in the terminal — every check in this lab writes down which condition it was not happy with, rather than leaving you to guess.
