
<br>

[`inference-gateway`](https://killercoda.com/kylelaw/course/ckne/inference-gateway) installs an `InferencePool` and its endpoint picker with a single `helm install`, and spends four steps *tuning* what the picker does. This lab is the other half: **assembling one**, and finding out what the chart was quietly getting right.

The architecture is the same, and every piece of it is an object you can read:

```plain
Gateway ─→ HTTPRoute ─→ backendRef: InferencePool ─→ endpointPickerRef: Service ─→ EPP
                                    │                                               │
                                    └──── selector ────→ model server Pods ←── scrapes
```

Already running here: Istio as the Gateway API implementation (gateway only, no sidecars), three replicas of a vLLM simulator labelled `app=vllm-qwen3-32b`, a `Gateway` named `inference-gateway`, and the endpoint picker itself — a Deployment, a Service, a ServiceAccount and its RBAC.

**The two objects in the middle are missing.** Writing them is step 1.

After that, three failures that all look like the service is down and are nothing of the kind. In each one the picker is running, the objects report themselves healthy, and requests fail anyway.

Two helpers are installed. `poolcall` sends one request and prints the status code **and how long it took** — the timing turns out to matter, because a failure returned in under a millisecond never reached a model server. `pickerlog` shows the picker's own pods and any errors it is logging; most of this lab is legible there and nowhere else.

Each step is checked with the **CHECK** button. When a check does not pass, run `why`{{exec}} in the terminal — every check in this lab writes down which condition it was not happy with, rather than leaving you to guess.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
