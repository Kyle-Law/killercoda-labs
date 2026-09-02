
The simulator is already running and serving `/metrics`. Confirm that first:

```plain
curl -s http://localhost:30800/metrics | grep '^vllm:' | head
```{{exec}}

Now deploy Prometheus to scrape it, so those values become a queryable time series rather than a snapshot.

Create:

- a ConfigMap named `prom-config` with a `prometheus.yml` that scrapes the `sim` Service on port `8000` every **5s**, under job name `vllm-sim`
- a Deployment named `prometheus` running `prom/prometheus:v3.1.0`
- a Service named `prometheus` of type **NodePort** on node port **30900**

Then confirm the target is `up`.

<br>

<details><summary>Info: why a 5s scrape interval</summary>

The default is 15s. Queue depth is a **gauge** — it only shows a value while requests are actually queued, so a slow scrape can miss a spike entirely. 5s makes transient saturation visible, which step 3 depends on.

</details>

<details><summary>Tip</summary>

Prometheus needs a writable data directory. An `emptyDir` works, but the container runs as uid `65534`, so the Pod needs `securityContext.fsGroup: 65534` or it can't write to it.

Inside the cluster the simulator is reachable at `sim:8000` — the Service name.

</details>

<details><summary>Solution</summary>

```plain
cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: prom-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 5s
    scrape_configs:
      - job_name: vllm-sim
        static_configs:
          - targets: ['sim:8000']
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      securityContext:
        fsGroup: 65534
      containers:
        - name: prometheus
          image: prom/prometheus:v3.1.0
          args:
            - --config.file=/etc/prometheus/prometheus.yml
            - --storage.tsdb.path=/prometheus
          ports:
            - containerPort: 9090
          volumeMounts:
            - name: config
              mountPath: /etc/prometheus
            - name: data
              mountPath: /prometheus
      volumes:
        - name: config
          configMap:
            name: prom-config
        - name: data
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
spec:
  type: NodePort
  selector:
    app: prometheus
  ports:
    - port: 9090
      targetPort: 9090
      nodePort: 30900
YAML
```{{exec}}

```plain
kubectl rollout status deployment/prometheus
```{{exec}}

Ask Prometheus whether the target is healthy:

```plain
curl -s 'http://localhost:30900/api/v1/query?query=up{job="vllm-sim"}'
```{{exec}}

A `"value"` of `1` means it's scraping successfully. Confirm the vLLM series arrived:

```plain
curl -s 'http://localhost:30900/api/v1/label/__name__/values' | tr ',' '\n' | grep vllm | head
```{{exec}}

</details>
