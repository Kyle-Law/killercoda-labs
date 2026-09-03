
Last one, and it's the whole lab in a single side-by-side.

podinfo has two flags that make it permanently fail one check or the other: `--unhealthy` makes `/healthz` never return OK, `--unready` does the same to `/readyz`. Same image, same kind of breakage — the only difference is which probe is watching.

Deploy **both**:

- `fails-liveness` — runs with `--unhealthy`, and has a `livenessProbe` on `/healthz`
- `fails-readiness` — runs with `--unready`, and has a `readinessProbe` on `/readyz`

Give both probes `periodSeconds: 3` and `failureThreshold: 2`. Then write down what you expect each one's `STATUS` and `RESTARTS` to be before you look.

<br>

<details><summary>Tip</summary>

`command: ["./podinfo","--unhealthy"]` and `command: ["./podinfo","--unready"]` — the binary sits in the image's working directory.

Give them a minute after rollout before judging; a restart loop needs a few cycles before it's unmistakable.

</details>

<details><summary>Solution</summary>

```plain
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fails-liveness
spec:
  replicas: 1
  selector:
    matchLabels:
      app: fails-liveness
  template:
    metadata:
      labels:
        app: fails-liveness
    spec:
      containers:
      - name: app
        image: ghcr.io/stefanprodan/podinfo:6.5.4
        command: ["./podinfo","--unhealthy"]
        ports:
        - containerPort: 9898
        livenessProbe:
          httpGet:
            path: /healthz
            port: 9898
          periodSeconds: 3
          failureThreshold: 2
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fails-readiness
spec:
  replicas: 1
  selector:
    matchLabels:
      app: fails-readiness
  template:
    metadata:
      labels:
        app: fails-readiness
    spec:
      containers:
      - name: app
        image: ghcr.io/stefanprodan/podinfo:6.5.4
        command: ["./podinfo","--unready"]
        ports:
        - containerPort: 9898
        readinessProbe:
          httpGet:
            path: /readyz
            port: 9898
          periodSeconds: 3
          failureThreshold: 2
YAML
```{{exec}}

```plain
sleep 75
kubectl get pods -l app=fails-liveness
kubectl get pods -l app=fails-readiness
```{{exec}}

`fails-liveness` is in **`CrashLoopBackOff`** with a restart count in the several. `fails-readiness` is **`Running`**, `0/1`, with **`0`** restarts — and it will sit there indefinitely, costing nothing, until whatever it's waiting on comes back.

<br>

<details><summary>Info: why this decides your blast radius</summary>

The failure that matters most in production is a **shared dependency** — a database, a cache, an auth service — going away. Every replica sees it at the same moment.

- Health-check that dependency in **readiness**: every replica leaves the load balancer, the Service serves nothing, and the instant the dependency returns they all come back on their own. Bad, but self-healing.
- Health-check it in **liveness**: every replica gets `SIGKILL`ed at the same moment, simultaneously, over and over. Now you have a restart storm hammering a dependency that was already struggling, and Pods that cannot stay up long enough to recover even after it comes back.

Hence the rule this lab has been building toward: **liveness probes check only whether *this process* is wedged.** Anything the container cannot fix by dying belongs in readiness — or in no probe at all.

</details>

</details>
