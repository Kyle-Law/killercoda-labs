
The node is `Ready` and Pods have addresses, so it is tempting to call that a pod network. Test that claim before you believe it.

Apply a NetworkPolicy that denies **all** ingress to `web`, then send it a request. Explain what you see.

Then install a real CNI, get the existing Pods onto it, and confirm the same policy — unchanged, never re-applied — starts doing something.

<br>

<details><summary>Tip</summary>

`websvc` sends one HTTP request to the `web` Service from a throwaway Pod and prints the backend that answered plus the exit code:

```plain
websvc
```{{exec}}

A default-deny ingress policy is a `podSelector` that matches `web`, a `policyTypes` naming `Ingress`, and no rules at all.

Helm and the Cilium repo are already set up. `ipam.mode=kubernetes` tells it to allocate out of `node.spec.podCIDR` — the same slice you used by hand in step 1:

```plain
helm install cilium cilium/cilium --version 1.19.7 --namespace kube-system --set ipam.mode=kubernetes
```

One thing will not fix itself. A CNI only manages Pods it set up, and every Pod currently running was wired by the plugins you named in step 1.

</details>

<details><summary>Solution</summary>

```plain
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-to-web
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes: [Ingress]
EOF
kubectl get netpol
```{{exec}}

Accepted, stored, listed. Now use it:

```plain
websvc
```{{exec}}

> ```
> web-ff6645ff4-zfkjn
> exit code: 0
> ```

The request went straight through. Nothing failed, nothing warned, and `kubectl get netpol` will go on showing the policy for as long as you leave it there.

**A NetworkPolicy is an ordinary API object.** The API server validates it and writes it to etcd, and that is the end of the API server's involvement. Enforcement is entirely the CNI's job — and `ptp` and `host-local` are an interface plumber and an address allocator. Neither has ever heard of a policy. There is no error for this, no event, no condition: the only way to find out is to test a connection you expect to be blocked.

That is the difference between having addresses and having a network. Install something that is actually a CNI:

```plain
helm install cilium cilium/cilium --version 1.19.7 \
  --namespace kube-system \
  --set ipam.mode=kubernetes
kubectl -n kube-system rollout status ds/cilium --timeout=300s
```{{exec}}

```plain
websvc
```{{exec}}

> Still `exit code: 0`. The policy is still not being enforced.

This catches people out during real CNI migrations. Cilium manages endpoints *it* created, and every Pod running right now was set up by the hand-written config — as far as Cilium is concerned they aren't there. They have to be recreated:

```plain
kubectl get pods -A -o go-template='{{range .items}}{{if not .spec.hostNetwork}}{{.metadata.namespace}}{{" "}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' \
  | while read -r NS POD; do kubectl -n "$NS" delete pod "$POD" --wait=false; done
kubectl rollout status deployment/web --timeout=180s
```{{exec}}

```plain
websvc
```{{exec}}

> ```
> wget: download timed out
>
> exit code: 1
> ```

The policy hasn't changed. Nobody re-applied it. What changed is that something on the node now reads it.

> **`hostNetwork` Pods were skipped on purpose, and this is a security point, not a housekeeping one.** They never had an address from the pod network, so there was nothing to recreate — and for the same reason, NetworkPolicy does not apply to them. "Contain the compromised Pod with a deny-all policy" quietly does nothing to a `hostNetwork` Pod.

Take the policy off again — later steps need `web` reachable:

```plain
kubectl delete netpol deny-all-to-web
websvc
```{{exec}}

</details>
