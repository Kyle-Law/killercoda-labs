
A real inference server has two different questions to answer: *"are you alive?"* and *"should I send you traffic?"* The simulator exposes both, and they are not the same endpoint.

**1.** Add both probes to the container in the Deployment:

```yaml
          livenessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 5
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8000
            initialDelaySeconds: 3
            periodSeconds: 5
```

**2.** Then use the simulator's failure injection to make it return errors on demand, and save one failing response's status code to `/root/injected-status`.

<br>

<details><summary>Info: the two endpoints, and why both</summary>

- `/health` — the process is up and serving. If this fails, restarting helps, so it belongs on **liveness**.
- `/health/ready` — the server is genuinely ready to accept work. On a real vLLM this covers the GPU being warmed and the model loaded, which can take minutes after the process starts. Restarting wouldn't help; you just need to wait, so it belongs on **readiness**.

Getting these backwards is a classic outage: a liveness probe pointed at a slow readiness check restarts the Pod forever and it never finishes starting.

</details>

<details><summary>Info: deterministic failure injection</summary>

The simulator can fail on request, without any config change, via a header:

```plain
X-Return-Error: 503
```

It returns exactly that status. There's also a probabilistic `--failure-injection-rate`, but the header is deterministic — much better for a test you want to be repeatable.

</details>

<details><summary>Solution</summary>

Either `kubectl edit deployment sim` and paste the two probes into the container, or apply the finished Deployment:

```plain
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sim
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sim
  template:
    metadata:
      labels:
        app: sim
    spec:
      containers:
        - name: sim
          image: ghcr.io/llm-d/llm-d-inference-sim:v0.11.2
          args: ["--config", "/config/config.yaml"]
          ports:
            - containerPort: 8000
          volumeMounts:
            - name: config
              mountPath: /config
          livenessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 5
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8000
            initialDelaySeconds: 3
            periodSeconds: 5
      volumes:
        - name: config
          configMap:
            name: sim-config
YAML
```{{exec}}

```plain
kubectl rollout status deployment/sim
kubectl get pods -l app=sim
```{{exec}}

A normal request still succeeds:

```plain
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:30800/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"dummy-model","messages":[{"role":"user","content":"fine"}]}'
```{{exec}}

The same request with the header fails, on demand:

```plain
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:30800/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -H 'X-Return-Error: 503' \
  -d '{"model":"dummy-model","messages":[{"role":"user","content":"fail"}]}' \
  | tee /root/injected-status
```{{exec}}

</details>

<br>

> Note the Pod stays `Ready` throughout. Injected request errors are not health failures — which is exactly the distinction you'd want when testing how a router or autoscaler reacts to a degraded backend.
