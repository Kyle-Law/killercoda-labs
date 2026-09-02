
Deploy the simulator and make it answer an OpenAI API call.

Create:

- a Deployment named `sim` running `ghcr.io/llm-d/llm-d-inference-sim:v0.11.2`, serving a model called `dummy-model` on port `8000`
- a Service named `sim` of type **NodePort** on node port **30800**

Then call it and save the model list to `/root/models.json`.

<br>

<details><summary>Info: why no GPU and no model download</summary>

The simulator never loads weights — it generates responses from a probabilistic model of what vLLM *would* return. `--model` is just the name it reports and answers to; any string works.

Leave `--render-url` unset. It only matters when you want real HuggingFace tokenisation, which is what upstream's heavyweight sidecar provides. Unset, the simulator uses its built-in tokenizer.

</details>

<details><summary>Tip</summary>

```plain
kubectl create deployment -h
```{{exec}}

Arguments after `--` on `kubectl create deployment` become the container's args.

The OpenAI endpoint for listing models is `GET /v1/models`.

</details>

<details><summary>Solution</summary>

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
          args: ["--model", "dummy-model", "--port", "8000"]
          ports:
            - containerPort: 8000
---
apiVersion: v1
kind: Service
metadata:
  name: sim
spec:
  type: NodePort
  selector:
    app: sim
  ports:
    - port: 8000
      targetPort: 8000
      nodePort: 30800
YAML
```{{exec}}

```plain
kubectl rollout status deployment/sim
```{{exec}}

Ask it which models it serves:

```plain
curl -s -w '\n' http://localhost:30800/v1/models
```{{exec}}

```plain
curl -s http://localhost:30800/v1/models > /root/models.json
```{{exec}}

Now send it an actual chat completion — the same request shape you'd send to OpenAI or a real vLLM:

```plain
curl -s -w '\n' http://localhost:30800/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"dummy-model","messages":[{"role":"user","content":"Hello there"}]}'
```{{exec}}

</details>
