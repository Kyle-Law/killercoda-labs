
`web`'s Service has no `ClusterIP` — it's headless, which means it doesn't load-balance. Instead, **each Pod** in the StatefulSet gets its own DNS entry: `web-0.web.default.svc.cluster.local`.

Using `dns-client`, resolve that name and write the IP address it returns into `/root/web0-dns-ip.txt`.

<br>

<details><summary>Tip</summary>

```
kubectl get svc web
kubectl exec dns-client -- nslookup web.default.svc.cluster.local
```{{exec}}

Compare a lookup of the Service name alone (`web`) against a lookup of one specific Pod's name (`web-0.web`).

</details>

<details><summary>Solution</summary>

```
kubectl exec dns-client -- nslookup web-0.web.default.svc.cluster.local
```{{exec}}

```
kubectl get pod web-0 -o jsonpath='{.status.podIP}'
```{{exec}}

Those two IPs match. Write the address into the file:

```
echo "<the-ip-you-found>" > /root/web0-dns-ip.txt
```{{exec}}

</details>
