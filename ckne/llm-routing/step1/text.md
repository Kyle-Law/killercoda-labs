
Put a `Gateway` named `llm-gateway` in front of the model servers, with an `HTTPRoute` named `chat-route` sending traffic to the **`chat-slow`** Service.

Then stream one long completion through it and watch what you get back.

The response will not arrive intact. Work out what cut it off, and fix it so the whole answer streams through.

<br>

<details><summary>Tip</summary>

```plain
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: llm-gateway
spec:
  gatewayClassName: eg
  listeners:
  - name: http
    protocol: HTTP
    port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: chat-route
spec:
  parentRefs:
  - name: llm-gateway
  rules:
  - backendRefs:
    - name: chat-slow
      port: 80
EOF
```{{exec}}

`chat-slow` runs in echo mode, so the reply is as long as the prompt — a 50-word prompt is a 50-token answer at 400ms each. Stream it:

```plain
GW=$(gwaddr)
PROMPT=$(awk 'BEGIN{for(i=1;i<=50;i++) printf "word%d ", i}')
kubectl exec cli -- curl -s -N -m 150 -o /tmp/s.txt \
  -w 'elapsed=%{time_total}s http=%{http_code}\n' \
  -X POST "http://$GW/v1/chat/completions" -H 'Content-Type: application/json' \
  -d "{\"model\":\"demo-model\",\"messages\":[{\"role\":\"user\",\"content\":\"$PROMPT\"}],\"max_tokens\":200,\"stream\":true}"
```{{exec}}

A complete SSE stream ends with a `data: [DONE]` marker. Count the chunks, and check whether that marker arrived.

</details>

<details><summary>Solution</summary>

```plain
GW=$(gwaddr)
PROMPT=$(awk 'BEGIN{for(i=1;i<=50;i++) printf "word%d ", i}')
kubectl exec cli -- curl -s -N -m 150 -o /tmp/s.txt \
  -w 'elapsed=%{time_total}s http=%{http_code}\n' \
  -X POST "http://$GW/v1/chat/completions" -H 'Content-Type: application/json' \
  -d "{\"model\":\"demo-model\",\"messages\":[{\"role\":\"user\",\"content\":\"$PROMPT\"}],\"max_tokens\":200,\"stream\":true}"
echo "chunks: $(kubectl exec cli -- grep -c '^data:' /tmp/s.txt)"
echo "[DONE]: $(kubectl exec cli -- grep -c 'DONE' /tmp/s.txt)"
```{{exec}}

> ```
> elapsed=16.0s http=200
> chunks: 36
> [DONE]: 0
> ```

Read those three lines carefully, because the combination is the whole problem:

- **`http=200`.** The response started fine, and the status code was sent long before anything went wrong.
- **`[DONE]: 0`.** The stream never finished. The answer is truncated mid-sentence.
- **`elapsed=16s`**, for a response that needed about 21.

**And the status code is the one everything downstream records.** `curl` does notice the connection closed early and exits `18` (partial transfer), but that signal lives only in the transport — the HTTP status was `200`, sent twenty seconds before the truncation happened, because a status code is committed the moment the response *starts*. Every access log, dashboard and SLO built on status codes shows this request as a success. A user sees an answer that simply stops mid-sentence.

The cause is Envoy's default route timeout of 15 seconds — an entirely sensible default for an API call, and completely wrong for a generation that streams for a minute. Gateway API lets you set it per route:

```plain
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: chat-route
spec:
  parentRefs:
  - name: llm-gateway
  rules:
  - timeouts:
      request: "0s"
      backendRequest: "0s"
    backendRefs:
    - name: chat-slow
      port: 80
EOF
sleep 10
```{{exec}}

```plain
kubectl exec cli -- curl -s -N -m 150 -o /tmp/s2.txt \
  -w 'elapsed=%{time_total}s http=%{http_code}\n' \
  -X POST "http://$GW/v1/chat/completions" -H 'Content-Type: application/json' \
  -d "{\"model\":\"demo-model\",\"messages\":[{\"role\":\"user\",\"content\":\"$PROMPT\"}],\"max_tokens\":200,\"stream\":true}"
echo "chunks: $(kubectl exec cli -- grep -c '^data:' /tmp/s2.txt)"
echo "[DONE]: $(kubectl exec cli -- grep -c 'DONE' /tmp/s2.txt)"
```{{exec}}

> ```
> elapsed=20.6s  chunks: 53  [DONE]: 1
> ```

`0s` means *no timeout*, which is the right answer for a streaming endpoint and the wrong answer almost everywhere else — an unbounded timeout on a normal API route is how you accumulate stuck connections. Scope it to the routes that stream.

> **The general lesson.** Streaming inverts what a timeout means. For a normal request, "15 seconds with no response" is a solid failure signal. For a stream, the response began immediately and is arriving steadily — the total simply exceeds any duration that made sense for a REST call. Timeouts along that path (proxy, ingress, service mesh, client SDK, browser) all need to agree, and the shortest one silently wins.

</details>
