
A default CNI install is the floor, not the goal. Two features the rest of the CKNE material depends on are off right now: flow visibility, and the eBPF replacement for `kube-proxy`.

Turn both on. Then prove each is genuinely doing the work rather than merely being configured — for the datapath in particular, "the Service still resolves" proves nothing on its own, and you should be able to say why.

<br>

<details><summary>Tip</summary>

Record what `kube-proxy` looks like *before* you change anything, or you'll have nothing to compare against:

```plain
iptables-save -t nat | grep -c KUBE
iptables-save -t nat | grep "default/web"
```{{exec}}

`helm upgrade --reuse-values` keeps the settings from step 2. The three you need are `kubeProxyReplacement`, `hubble.relay.enabled`, and — since `kube-proxy` is about to be gone — telling Cilium how to reach the API server without it.

Deleting the `kube-proxy` DaemonSet stops it programming new rules. It does not remove the ones already there, and that is exactly why "the Service still works" is not evidence.

</details>

<details><summary>Solution</summary>

Take the baseline first:

```plain
iptables-save -t nat | grep -c KUBE
iptables-save -t nat | grep "default/web"
```{{exec}}

> ```
> 68
> -A KUBE-SERVICES -d 10.96.146.85/32 -p tcp ... -j KUBE-SVC-LOLE4ISW44XBNF3G
> -A KUBE-SVC-LOLE4ISW44XBNF3G ... -j KUBE-SEP-CGQFHQLKDQWHG7RJ
> -A KUBE-SEP-CGQFHQLKDQWHG7RJ -p tcp ... -j DNAT --to-destination 10.244.0.71:8080
> ```

That is a Service, concretely: a ClusterIP matched in `KUBE-SERVICES`, a per-Service chain that picks a backend, and a per-endpoint chain that DNATs to a Pod address. Now replace it:

```plain
API_IP=$(kubectl get node -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
helm upgrade cilium cilium/cilium --version 1.19.7 --namespace kube-system --reuse-values \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost="$API_IP" \
  --set k8sServicePort=6443 \
  --set hubble.relay.enabled=true
kubectl -n kube-system delete ds kube-proxy
kubectl -n kube-system rollout restart ds/cilium
kubectl -n kube-system rollout status ds/cilium --timeout=300s
```{{exec}}

> `k8sServiceHost` is not optional here. Cilium normally reaches the API server through the `kubernetes` Service — which is a ClusterIP, which is the thing it is about to take over providing. Point it at the node address and port directly, or it cannot bootstrap.

Now the trap:

```plain
iptables-save -t nat | grep -c KUBE
websvc
```{{exec}}

> Still `68` rules, and the request succeeds.

**Deleting a DaemonSet does not undo what it wrote.** `kube-proxy`'s rules are still in the kernel and still perfectly capable of routing that request. A green result here would tell you nothing about whether the replacement works, because you haven't removed the thing it replaces. Clear them out:

```plain
for t in nat mangle filter; do
  iptables-save -t $t | grep -v -E "^:KUBE|KUBE-" | iptables-restore -T $t
done
iptables-save -t nat | grep -c KUBE
```{{exec}}

```plain
websvc
```{{exec}}

> `0` rules, and the Service still answers. *Now* it's evidence.

Ask where the mapping went:

```plain
kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status | grep KubeProxyReplacement
kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg service list
```{{exec}}

> ```
> KubeProxyReplacement:    True   [eth0  172.19.0.6 (Direct Routing)]
>
> ID   Frontend               Service Type   Backend
> 2    10.96.146.85:80/TCP    ClusterIP      1 => 10.244.0.71:8080/TCP (active)
> ```

The same ClusterIP, the same backend, the same DNAT — held in an eBPF map instead of an iptables chain. iptables evaluates rules in sequence, so cost grows with the number of Services; a hash map lookup does not. That is the whole argument for the replacement, and it is why this is the datapath most large clusters end up on.

Now the other half. Hubble was switched on in the same upgrade — check it is actually collecting:

```plain
kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status | grep Hubble
```{{exec}}

> `Hubble:  Ok   Current/Max Flows: 92/4095 (2.25%), Flows/s: 12.60`

Flows per second, not "enabled". Point it at the thing you couldn't see in step 2 — put the deny-all policy back, make the request fail, and ask Hubble why:

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
sleep 5
websvc
```{{exec}}

```plain
kubectl -n kube-system exec ds/cilium -c cilium-agent -- hubble observe --last 200 --verdict DROPPED
```{{exec}}

> ```
> default/svccheck:37220 <> default/web-ff6645ff4-nww7l:8080 Policy denied DROPPED (TCP Flags: SYN)
> ```

In step 2 the identical policy was enforced by nothing, and there was no way to tell except by testing a connection. Now the drop is a named event with a source, a destination, a port and a reason. `wget: download timed out` was all the application ever knew; this is the same packet from the other side.

Tidy up so the cluster is left working:

```plain
kubectl delete netpol deny-all-to-web
websvc
```{{exec}}

</details>
