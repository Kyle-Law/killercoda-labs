
You have edited cluster DNS three times. Find out what a bad edit costs, before you find out in production.

Introduce a typo — misspell `forward` as `forwardd` — and apply it. Predict first: does cluster DNS go down?

Then work out why the answer is more dangerous than "yes" would have been, and prove it. Leave the cluster healthy at the end.

<br>

<details><summary>Tip</summary>

```plain
sed -i 's|^    forward \. /etc/resolv.conf|    forwardd . /etc/resolv.conf|' /root/Corefile
applycorefile
```{{exec}}

Then check whether DNS still resolves, and look at the CoreDNS Pods:

```plain
dnsq web.default.svc.cluster.local
corednsstatus
```{{exec}}

For the second half: the running Pods rejected the change and carried on. Ask what a *new* CoreDNS Pod would do — it has no last-known-good configuration to fall back on. Something as ordinary as a node drain would create one.

</details>

<details><summary>Solution</summary>

```plain
sed -i 's|^    forward \. /etc/resolv.conf|    forwardd . /etc/resolv.conf|' /root/Corefile
applycorefile
```{{exec}}

> ```
> ConfigMap updated. Waiting for CoreDNS to reload..... REJECTED after 25s
> [ERROR] plugin/reload: Corefile changed but reload failed: ... Error during parsing: Unknown directive 'forwardd'
>
> CoreDNS kept the last configuration that parsed. Cluster DNS is still up.
> ```

```plain
dnsq web.default.svc.cluster.local
dnsq db.corp.internal
corednsstatus
```{{exec}}

> Everything resolves. Both Pods `1/1 Running`, `0` restarts.

The `reload` plugin parses the new Corefile *before* swapping it in, and on a parse error it keeps serving the old one. That is good engineering. It is also why this is the failure mode to be afraid of:

- `kubectl apply` succeeded.
- `kubectl get cm coredns` shows your broken config, and it is now the desired state.
- Every lookup works.
- Nothing is `NotReady`, no alert fires, and the error is one line in a log nobody tails.

The cluster is in a state where **the stored configuration and the running configuration disagree, and only the running one is any good.** Now do the ordinary thing that resolves that disagreement — a drain, an eviction, a node restart, a scale-up:

```plain
POD=$(kubectl -n kube-system get pods -l k8s-app=kube-dns -o jsonpath='{.items[0].metadata.name}')
echo "deleting $POD"
kubectl -n kube-system delete pod $POD --wait=false
sleep 50
kubectl -n kube-system get pods -l k8s-app=kube-dns
```{{exec}}

> ```
> coredns-559f6c778d-7bqcn   0/1   CrashLoopBackOff   3 (17s ago)   50s
> coredns-559f6c778d-vlw9s   1/1   Running            0             7m37s
> ```

```plain
NEW=$(kubectl -n kube-system get pods -l k8s-app=kube-dns --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')
kubectl -n kube-system logs $NEW --tail=3
dnsq web.default.svc.cluster.local
```{{exec}}

> ```
> /etc/coredns/Corefile:14 - Error during parsing: Unknown directive 'forwardd'
> ```
> and DNS still works.

**That is the shape of the incident.** The change that broke DNS and the event that revealed it are separated by however long it takes for a Pod to restart — an afternoon, a week, whenever the cluster is next upgraded. Half of CoreDNS is already gone and DNS still answers, so nothing looks wrong until the last replica goes, at which point everything in the cluster fails to resolve anything and the Corefile change is no longer anywhere near the top of anyone's list of suspects.

The defence is not cleverness, it's sequencing: **after any Corefile change, confirm the reload succeeded and that every CoreDNS Pod is `Running` with no new restarts.** `applycorefile` refused this change loudly for exactly that reason. A plain `kubectl apply` would not have.

Put it back — and this time apply it the plain way, because the recovery has a detail worth seeing:

```plain
sed -i 's/forwardd/forward/' /root/Corefile
kubectl -n kube-system create configmap coredns --from-file=Corefile=/root/Corefile \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n kube-system rollout status deployment/coredns --timeout=240s
kubectl -n kube-system get pods -l k8s-app=kube-dns
```{{exec}}

> Both Pods `1/1 Running`. The recovered one has restart counts on it; the other has none.

**Nothing reloaded.** The surviving replica was already running this exact configuration — reverting the typo restored the bytes it never stopped serving — so there was no change for `reload` to pick up. The only Pod that needed anything was the one that couldn't parse the stored config, and it recovered by itself the moment the ConfigMap became valid.

That is the asymmetry to take away: a bad Corefile is invisible to a running CoreDNS and fatal to a starting one, and so is the fix.

```plain
dnsq web.default.svc.cluster.local
dnsq db.corp.internal
dnsq legacy-api.example.com
```{{exec}}

The CrashLooping Pod picks itself up as soon as the ConfigMap parses — no delete, no rollout restart needed. All three names resolve: the Service, the stub domain, and the rewrite.

</details>
