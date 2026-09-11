
The last fault is different, and it is the one that gets misfiled as an application bug.

Run the probe. **The small object succeeds. The large one hangs and transfers zero bytes.** Ping works. The connection establishes. Nothing is dropped by any firewall on any hop.

Find out why size matters, write the MTU value you find to `/root/answers/step4.txt`, and fix it.

<br>

<details><summary>Tip</summary>

```plain
netlab test
```{{exec}}

The handshake completes, so this is not a connectivity problem in the usual sense — something fails only once real data starts moving.

Capture the *server's* outbound full-size segments and watch what it does:

```plain
netlab srv timeout 8 tcpdump -nn -i vs0 'tcp and src 10.10.2.2 and len > 1000' -c 6 > /tmp/big.txt 2>&1 &
sleep 1
netlab cli curl -m 6 -sS -o /dev/null http://10.10.2.2:8080/big.bin
sleep 8
grep -oE 'seq [0-9]+:[0-9]+' /tmp/big.txt
```{{exec}}

When a packet is too big for a link and cannot be fragmented, the router is supposed to say so. Check whether that message ever arrives:

```plain
netlab srv timeout 8 tcpdump -nn -i vs0 icmp > /tmp/icmp.txt 2>&1 &
```

And compare the MTU of every interface along the path.

</details>

<details><summary>Solution</summary>

```plain
netlab test
```{{exec}}

> ```
> small.txt:  http 200   3 bytes        0.002s
> big.bin:    curl: (28) ... 0 out of 2000000 bytes received
> ```

Zero bytes of a two-megabyte file, after the connection succeeded. Watch what the server is actually sending:

```plain
netlab srv timeout 8 tcpdump -nn -i vs0 'tcp and src 10.10.2.2 and len > 1000' -c 6 > /tmp/big.txt 2>&1 &
sleep 1
netlab cli curl -m 6 -sS -o /dev/null http://10.10.2.2:8080/big.bin
sleep 8
grep -oE 'seq [0-9]+:[0-9]+' /tmp/big.txt
```{{exec}}

> ```
> seq 7240:14480          <- leftovers from the handshake and earlier probes
> seq 14480:15928
> seq 0:1448
> seq 0:1448
> seq 0:1448
> ```

Ignore the first few — they are tail ends of earlier connections. What matters is where the list **stops advancing**: `seq 0:1448`, over and over.

**The same segment, the same sequence number, retransmitted forever.** The server is not confused about what to send — it is sending it repeatedly and never being acknowledged. Something between here and the client is swallowing that segment specifically, while the small ones get through.

A full-size segment that cannot cross a link should produce an ICMP "fragmentation needed" back to the sender. Check whether one ever arrives:

```plain
netlab srv timeout 8 tcpdump -nn -i vs0 icmp > /tmp/icmp.txt 2>&1 &
sleep 1
netlab cli curl -m 5 -sS -o /dev/null http://10.10.2.2:8080/big.bin
sleep 8
grep -c ICMP /tmp/icmp.txt
```{{exec}}

> `0`. Nothing. The server is never told, so it never lowers its segment size — it just keeps resending.

Now find the narrow link:

```plain
netlab cli ip link show vc0 | head -1
netlab rtr ip link show vr0 | head -1
netlab rtr ip link show vr1 | head -1
netlab srv ip link show vs0 | head -1
```{{exec}}

> `vr0` on the router is `mtu 1400`. Everything else is `1500`.

That is a **PMTU black hole**, and it needs both halves to exist: a link too small for the traffic, *and* the ICMP that would have reported it being discarded.

```plain
netlab rtr iptables -L OUTPUT -n -v
```{{exec}}

> A `DROP` rule matching `icmp type 3 code 4` — fragmentation-needed, filtered on the very router that generates it.

Note the direction: `vr0` is the interface the router **transmits on toward the client**, and the bulk data flows server→client. A narrow link on `vr1` would have constrained only ACKs and the request, and nothing would have broken at all.

```plain
echo "PMTU black hole: rtr vr0 mtu 1400, ICMP frag-needed dropped in OUTPUT" > /root/answers/step4.txt
netlab rtr ip link set vr0 mtu 1500
netlab rtr iptables -D OUTPUT -p icmp --icmp-type fragmentation-needed -j DROP
netlab test
```{{exec}}

Either half of the fix works on its own, and they fail differently:

- **Raise the MTU** — the segments now fit, and nothing needs to be reported.
- **Stop filtering the ICMP** — the segments still do not fit, but now the server is *told*, lowers its segment size, and the transfer completes over slightly smaller packets.

In production you often control neither hop, so the third option is to stop the problem arising: clamp the advertised segment size to whatever the path can actually carry, at connection setup.

```plain
netlab rtr iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
```

> **Why this is worth recognising on sight:** it is invisible to every reachability test anyone reaches for first. Ping succeeds (small packets). The connection opens (small packets). Health checks pass (small responses). Only large responses fail, which looks exactly like an application that is broken for some requests and fine for others — and the investigation goes to the wrong team for a day.

</details>
