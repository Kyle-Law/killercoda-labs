
Route 80% of `web.example.com` traffic to `web`, and 20% to `web-canary` — a single rule, no path or header involved, splitting *within* one match.

Then don't trust the number. Send 200 requests and count where they actually landed.

<br>

<details><summary>Tip</summary>

`backendRefs` is a list, and each entry can carry its own `weight`:

```plain
kubectl explain httproute.spec.rules.backendRefs.weight
```{{exec}}

To count 200 answers by which Pod served them:

```plain
GWIP=$(gwaddr)
kubectl exec client -- /bin/sh -c '
for i in $(seq 1 200); do
  wget -qO- -T3 --header="Host: web.example.com" http://'"$GWIP"'/hostname
  echo
done' | sort | uniq -c
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: web-route
spec:
  parentRefs:
  - name: web-gateway
    sectionName: public
  hostnames: ["web.example.com"]
  rules:
  - backendRefs:
    - name: web
      port: 80
      weight: 80
    - name: web-canary
      port: 80
      weight: 20
EOF
```{{exec}}

```plain
GWIP=$(gwaddr)
kubectl exec client -- /bin/sh -c '
for i in $(seq 1 200); do
  wget -qO- -T3 --header="Host: web.example.com" http://'"$GWIP"'/hostname
  echo
done' | sort | uniq -c
```{{exec}}

> ```
>  22 web-canary-55cfcb86b9-pbjzs
> 178 web-ff6645ff4-vrtcb
> ```

Close to 80/20, not exact — 200 independent random draws land near a ratio, they don't reproduce it exactly, the same way 200 flips of a biased coin won't land on precisely 160 heads. **The weight is a target the load balancer aims for over volume, not a guarantee any particular batch of requests will match it.** At low request counts — a health check, a handful of manual `curl`s while debugging — don't conclude a weighted split is broken from a sample that's nowhere near large enough to show it.

This is also the real value of `weight` over running two separate Deployments and eyeballing it: **the split lives entirely in the Gateway config, adjustable with one number, with no redeploy of either backend and no change to either Service.** Push `web`'s weight to 100 and `web-canary` to 0 to roll a canary forward; swap them to roll back. Nothing about `web` or `web-canary` themselves ever changes.

</details>
