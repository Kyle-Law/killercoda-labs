
<br>

`networking/ingress-and-gateway-api` models one Ingress-style route as a `Gateway` and an `HTTPRoute`, on a cluster where nothing actually reconciles them into traffic. This lab goes the other way: a real controller — [Envoy Gateway](https://gateway.envoyproxy.io/) — is installed and running, every request in every step goes through a real Envoy proxy, and every claim about routing behavior is something you'll watch happen rather than something you'll take on trust.

That matters because Gateway API's whole reason to exist is the routing Ingress genuinely cannot express, and none of it is visible from the object schema alone: which of several matching rules actually wins, whether a traffic split is holding its ratio, whether a route that looks correctly attached is quietly going nowhere. This lab is built to make you check.

Two backends are running — `web` and `web-canary`, identical images, different names, so you can always tell which one answered — plus a `GatewayClass` named `eg`, and a second, unrelated `web` in a separate `team-b` namespace. Nothing routes anywhere yet.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
