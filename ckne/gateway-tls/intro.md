
<br>

`ckne/httproute-in-depth` put real HTTP traffic through a real Envoy Gateway. Every request in that lab travelled in plaintext. This one puts TLS in front of the same kind of setup — a real certificate authority, a real handshake, a real renewal — because "the listener has a cert" and "the listener is serving the cert you think it is" are different claims, and only one of them is checkable by reading YAML.

`cert-manager` is installed, with a self-signed root CA (`lab-root-ca`) playing the part of an internal certificate authority, and a `ClusterIssuer` backed by it ready to sign anything asked of it. `web` and `web-canary` are running, same as before. Nothing is exposed over TLS yet.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
