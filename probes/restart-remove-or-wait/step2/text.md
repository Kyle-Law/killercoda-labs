
`slow-starter` is `READY 1/1` — because it currently has no liveness probe at all. A container that deadlocks now goes undetected forever, which is exactly the situation liveness probes exist for.

The obvious repair is to put liveness back with `initialDelaySeconds: 90`, comfortably past the 60-second startup. **Don't do that.** Work out what's wrong with it first, then implement the alternative.

Put liveness back so that both of these hold:

- the Pod survives its full 60-second startup, restart-free
- once running, a hung container is detected in **~10 seconds**, not 90

<br>

<details><summary>Tip</summary>

`initialDelaySeconds` is a blind window, and it applies on **every** start of the container — not just the first. Size it for the worst-case boot and you've bought that many seconds of no liveness checking, permanently. Size it too small and you're back to step 1's restart loop. There is no value that is simultaneously safe for a slow boot and quick to notice a hang.

A `startupProbe` splits those two jobs apart. While it is running, liveness and readiness are both suspended; the moment it succeeds it never runs again and the other two take over. So the startup budget lives in `failureThreshold × periodSeconds` on the startup probe, and liveness gets to stay tight.

```plain
kubectl explain pod.spec.containers.startupProbe
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: slow-starter
spec:
  replicas: 1
  selector:
    matchLabels:
      app: slow-starter
  template:
    metadata:
      labels:
        app: slow-starter
    spec:
      containers:
      - name: app
        image: ghcr.io/stefanprodan/podinfo:6.5.4
        command: ["/bin/sh","-c","sleep 60 && ./podinfo"]
        ports:
        - containerPort: 9898
        startupProbe:
          httpGet:
            path: /healthz
            port: 9898
          periodSeconds: 5
          failureThreshold: 30
        readinessProbe:
          httpGet:
            path: /readyz
            port: 9898
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /healthz
            port: 9898
          periodSeconds: 5
          failureThreshold: 2
YAML
```{{exec}}

```plain
kubectl rollout status deployment/slow-starter --timeout=180s
kubectl get pods -l app=slow-starter
```{{exec}}

`READY 1/1`, `RESTARTS 0`, with a liveness probe active — the thing step 1 could not achieve.

The startup probe allows `30 × 5s = 150 seconds` for the app to come up: generous, and costing nothing when the app is fast, because it stops the instant it first succeeds. Liveness then runs at `2 × 5s`, so a hang is caught in about 10 seconds — the tight interval you actually want in steady state, which was impossible to have while the same probe was also responsible for tolerating a 60-second boot.

</details>
