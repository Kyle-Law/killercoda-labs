
`veth-web.txt` names an ordinary network interface, sitting on the host. Prove that by watching one real request cross it.

Capture on it, make a plain HTTP request straight to `web`'s Pod IP — not the Service — and save what you see to `/root/cap-direct.txt`.

<br>

<details><summary>Tip</summary>

Start the capture in the background, with a packet count so it stops on its own, then make the request:

```plain
VETH=$(cat /root/veth-web.txt)
tcpdump -i $VETH -n -c 10 tcp > /root/cap-direct.txt 2>&1 &
sleep 1
```{{exec}}

Then, in the same terminal:

```plain
WEBPOD=$(kubectl get pod -l app=web -o jsonpath='{.items[0].metadata.name}')
PODIP=$(kubectl get pod -l app=web -o jsonpath='{.items[0].status.podIP}')
kubectl exec client -- wget -qO- -T5 http://$PODIP:8080/hostname
echo
sleep 2
cat /root/cap-direct.txt
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
VETH=$(cat /root/veth-web.txt)
tcpdump -i $VETH -n -c 10 tcp > /root/cap-direct.txt 2>&1 &
sleep 1
PODIP=$(kubectl get pod -l app=web -o jsonpath='{.items[0].status.podIP}')
kubectl exec client -- wget -qO- -T5 http://$PODIP:8080/hostname
echo
sleep 2
cat /root/cap-direct.txt
```{{exec}}

> ```
> 10.244.0.6.44584 > 10.244.0.5.8080: Flags [S] ...
> 10.244.0.5.8080 > 10.244.0.6.44584: Flags [S.] ...
> 10.244.0.6.44584 > 10.244.0.5.8080: Flags [.] ...
> 10.244.0.6.44584 > 10.244.0.5.8080: Flags [P.] ... HTTP: GET /hostname HTTP/1.1
> 10.244.0.5.8080 > 10.244.0.6.44584: Flags [P.] ... HTTP: HTTP/1.1 200 OK
> ...
> ```

The full exchange, on an interface whose name has never appeared in any Kubernetes object: three-way handshake, the request, the response, the four-way close. Nothing about this is Kubernetes-specific — it's a plain TCP connection on a plain Linux interface, which happens to have a container's network namespace grafted onto one end.

That's the standing fact this whole lab leans on: **whatever `kubectl` shows you as a Pod-to-Pod connection is, underneath, ordinary interfaces that `tcpdump` and `iptables` already know how to see.** No special Kubernetes-aware tooling was involved in capturing this.

</details>
