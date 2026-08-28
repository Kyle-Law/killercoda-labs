
Your starting point is one file:

```plain
cat /root/site/index.html
```{{exec}}

Get it served from Kubernetes using **`kubectl` only** — no Helm yet:

- a ConfigMap named `site` holding `index.html`
- a Deployment named `site` running `nginx:1.27-alpine`, with that ConfigMap mounted at `/usr/share/nginx/html`
- a Service named `site` of type **NodePort**, on node port **30080**

Then confirm the page is reachable with `curl localhost:30080`.

<br>

<details><summary>Tip</summary>

```plain
kubectl create configmap -h
kubectl create deployment -h
```{{exec}}

A ConfigMap can be built straight from a file with `--from-file`. Mounting it needs a `volume` + `volumeMounts` pair, which is easier to write as YAML than to reach with flags.

</details>

<details><summary>Solution</summary>

```plain
kubectl create configmap site --from-file=/root/site/index.html
```{{exec}}

```plain
cat <<'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: site
spec:
  replicas: 1
  selector:
    matchLabels:
      app: site
  template:
    metadata:
      labels:
        app: site
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine
          ports:
            - containerPort: 80
          volumeMounts:
            - name: site
              mountPath: /usr/share/nginx/html
      volumes:
        - name: site
          configMap:
            name: site
---
apiVersion: v1
kind: Service
metadata:
  name: site
spec:
  type: NodePort
  selector:
    app: site
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080
YAML
```{{exec}}

```plain
kubectl rollout status deployment/site
curl localhost:30080
```{{exec}}

</details>

<br>

It works — but the environment name is hardcoded in the HTML, the port is hardcoded in the Service, and shipping a second copy for `prod` means copying and editing all of it. That's the problem the rest of this scenario solves.
