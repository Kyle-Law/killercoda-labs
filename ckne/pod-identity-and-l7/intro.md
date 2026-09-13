
<br>

Native `NetworkPolicy` is an L3/L4 API. It can say *"`web` may reach `api` on port 8080"*. It cannot say *"`web` may `GET /hostname` but not `POST` anything"* — there is no field for it, because at the layer the API operates on, that distinction does not exist.

That is a real limit, not an oversight. Plenty of authorization rules people need are about methods and paths, and the usual answer is to push them into the application, or a sidecar, or give up.

This cluster runs Cilium, which extends policy above L4 with its own `CiliumNetworkPolicy` — HTTP method and path matching, enforced in the network rather than the app. This lab is about what that buys, what it costs, and the thing it changes underneath that catches people out.

Two workloads:

| Workload | Role |
|---|---|
| `api` | an HTTP server on port 8080, behind a Service on port 80 |
| `web` | the caller |

`try GET /hostname` sends one request and prints the status code. Watch that code closely throughout — **`000` and `403` mean completely different things**, and the difference tells you which layer refused you.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
