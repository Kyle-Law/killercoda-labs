
`web-route` has one rule and it matches everything. Give it three, all on the `public` listener, all still for `web.example.com`:

- Anything under `/` → `web` (the rule you already have).
- Exactly `/hostname`, **and only a `GET`** → `web-canary`.

Write the exact rule down, but before you apply it: **predict** which backend answers a `GET /hostname`. Both rules match that request — the general one and the specific one.

<br>

<details><summary>Tip</summary>

A `matches` entry can combine `path`, `method` and `headers` — all conditions inside one entry have to hold at once for that entry to match:

```plain
kubectl explain httproute.spec.rules.matches
```{{exec}}

`path.type: Exact` matches the literal string. `path.type: PathPrefix` matches it and everything under it — `/` matches every path there is.

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
  - matches:
    - path: {type: PathPrefix, value: /}
    backendRefs:
    - name: web
      port: 80
  - matches:
    - path: {type: Exact, value: /hostname}
      method: GET
    backendRefs:
    - name: web-canary
      port: 80
EOF
```{{exec}}

```plain
GWIP=$(gwaddr)
kubectl exec client -- wget -qO- -T5 --header="Host: web.example.com" "http://$GWIP:80/hostname"; echo
```{{exec}}

> `web-canary` answers — even though the exact+method rule is listed **second**, and the catch-all prefix rule is listed first and genuinely matches too.

**Order in the YAML has nothing to do with which rule wins.** Gateway API defines precedence by specificity: an exact path beats a prefix path, and — as you're about to see — matching on more fields beats matching on fewer, regardless of where either rule sits in the list.

Confirm the prefix rule still catches what the specific one doesn't — the exact rule requires `GET`, so send anything else to the same path:

```plain
kubectl exec client -- wget -qO- -T5 --post-data="" --header="Host: web.example.com" "http://$GWIP:80/hostname"; echo
```{{exec}}

> `web` answers this one. Identical path to the request that reached `web-canary` a moment ago — a `POST` instead of a `GET` is the only difference, and that alone is enough to fall through to the prefix rule.

Now leave the path alone and add specificity a different way. Swap the second rule's condition from a path to a header, still against the same catch-all prefix rule:

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
  - matches:
    - path: {type: PathPrefix, value: /}
    backendRefs:
    - name: web
      port: 80
  - matches:
    - path: {type: PathPrefix, value: /}
      headers:
      - name: x-canary
        value: "true"
    backendRefs:
    - name: web-canary
      port: 80
EOF
```{{exec}}

```plain
echo "--- no header ---"
kubectl exec client -- wget -qO- -T5 --header="Host: web.example.com" "http://$GWIP:80/hostname"; echo
echo "--- with x-canary: true ---"
kubectl exec client -- wget -qO- -T5 --header="Host: web.example.com" --header="x-canary: true" "http://$GWIP:80/hostname"; echo
```{{exec}}

> Identical path, identical `PathPrefix: /` on both rules. The only difference is one rule also names a header — and that's the entire reason it wins when the header is present. **A rule that matches on more conditions outranks one that matches on fewer, at equal path specificity.**

Both experiments demonstrate the same underlying rule: **precedence is decided by how specific a match is, never by declaration order.** The practical consequence is what makes canary releases and A/B rules safe to write in either order — a narrowly-targeted rule for one header, one method, one exact path will always be checked ahead of the broad rule sitting next to it, whichever one you happened to write first.

</details>
