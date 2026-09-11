
Three network namespaces are wired together, and something is broken:

```plain
cli 10.10.1.2  ──vc0───vr0──  rtr  ──vr1───vs0──  10.10.2.2 srv
                 10.10.1.0/24      10.10.2.0/24    :8080
```

Reproduce the failure, then answer two questions **before** you touch a capture:

- Does it **hang** or does it **fail instantly**? That single observation already rules out half the possible causes.
- Which of the three namespaces is the traffic dying in?

Then find the rule responsible, write the chain it lives in to `/root/answers/step1.txt`, and remove it so the probe passes again.

<br>

<details><summary>Tip</summary>

```plain
netlab test
```{{exec}}

Time it took to fail is data. A packet that is **dropped** leaves the sender waiting for a reply that never comes, until it gives up. A packet that is **rejected** gets an answer — an RST or an ICMP error — and the client knows immediately.

To find where it dies, capture progressively further along the path. `netlab cli`, `netlab rtr` and `netlab srv` each run a command inside that namespace:

```plain
netlab cli tcpdump -nn -i vc0 -c 3 tcp &
sleep 1
netlab cli curl -m 4 -sS -o /dev/null http://10.10.2.2:8080/small.txt
```{{exec}}

If the packet leaves `cli` and never reaches `srv`, the router is where to look. Counters tell you which rule matched:

```plain
netlab rtr iptables -L -n -v
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
netlab test
```{{exec}}

> Both objects fail with `curl exit 28` after the full 8-second timeout.

**A timeout, not an instant refusal.** Nothing sent an RST and nothing sent an ICMP error — the packets are being discarded silently. That already eliminates "nothing is listening" and any `REJECT` rule; those produce an answer, and an answer arrives fast.

Now find where. Capture at the client first:

```plain
netlab cli timeout 5 tcpdump -nn -i vc0 tcp -c 4 > /tmp/cli.txt 2>&1 &
sleep 1
netlab cli curl -m 3 -sS -o /dev/null http://10.10.2.2:8080/small.txt
sleep 5
cat /tmp/cli.txt
```{{exec}}

> SYNs going out, repeating with the same sequence number, nothing coming back. The client is doing its job.

Now the far side of the router — does anything get forwarded toward the server?

```plain
netlab rtr timeout 5 tcpdump -nn -i vr1 tcp -c 2 > /tmp/rtr.txt 2>&1 &
sleep 1
netlab cli curl -m 3 -sS -o /dev/null http://10.10.2.2:8080/small.txt
sleep 5
cat /tmp/rtr.txt
```{{exec}}

> `0 packets captured`. The packets arrive at the router and never leave it. **The loss is on `rtr`.**

Zero the counters, retry, and read which rule moved:

```plain
netlab rtr iptables -Z
netlab cli curl -m 3 -sS -o /dev/null http://10.10.2.2:8080/small.txt
netlab rtr iptables -L -n -v
```{{exec}}

> ```
> Chain FORWARD (policy ACCEPT 0 packets, 0 bytes)
>  pkts bytes target  prot opt in  out  source     destination
>     4   240 DROP    6    --  *   *    0.0.0.0/0  0.0.0.0/0    tcp dpt:8080
> ```

`FORWARD`, not `INPUT` — and that distinction is the point. `INPUT` is for packets addressed *to* this machine. These packets are addressed to `10.10.2.2`; the router is only carrying them. A rule in `INPUT` would never have matched them, and looking only at `INPUT` is a common way to miss a router-side drop entirely.

```plain
echo "FORWARD chain on rtr, DROP rule matching tcp dport 8080" > /root/answers/step1.txt
netlab rtr iptables -D FORWARD -p tcp --dport 8080 -j DROP
netlab test
```{{exec}}

> Both objects return `http 200`. Zeroing counters (`iptables -Z`) before re-testing is what made the culprit unambiguous — on a busy box, a rule with a large pre-existing count tells you much less than one that went from zero to four while you watched.

</details>
