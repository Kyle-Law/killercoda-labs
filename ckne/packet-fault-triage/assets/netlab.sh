#!/usr/bin/env bash
# netlab.sh - a packet-level debugging lab in network namespaces.
#
#   cli 10.10.1.2  ──vc0───vr0──  rtr  ──vr1───vs0──  10.10.2.2 srv
#                    10.10.1.0/24      10.10.2.0/24    :8080
#
# Nothing here touches your host's network stack: every address, route and
# firewall rule lives inside three throwaway namespaces.
#
#   netlab setup            build the topology
#   netlab test             run the standard client probe
#   netlab fault random     inject a fault without telling you which
#   netlab fault 5          inject a specific fault
#   netlab reveal           show the answer + how you should have found it
#   netlab reset            clear all faults, keep the topology
#   netlab teardown         delete everything
#   netlab cli|rtr|srv ...  run a command inside a namespace
#
# Requires: root, iproute2, iptables, nftables, tcpdump, curl, python3.

set -euo pipefail

CLI=plc-cli; RTR=plc-rtr; SRV=plc-srv
STATE=/run/packet-lab
WWW=$STATE/www
FAULTS=9

c() { ip netns exec $CLI "$@"; }
r() { ip netns exec $RTR "$@"; }
s() { ip netns exec $SRV "$@"; }

die()  { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }
note() { printf '\033[36m%s\033[0m\n' "$*"; }
ok()   { printf '\033[32m%s\033[0m\n' "$*"; }

need_root() { [ "$(id -u)" -eq 0 ] || die "must run as root"; }

need_tools() {
  local missing=()
  for t in ip iptables nft tcpdump curl python3; do
    command -v "$t" >/dev/null || missing+=("$t")
  done
  [ ${#missing[@]} -eq 0 ] || die "missing tools: ${missing[*]}"
}

exists() { ip netns list | grep -qw "$CLI"; }

# ----------------------------------------------------------------- setup ---
setup() {
  need_root; need_tools
  exists && { note "lab already up (use 'reset' or 'teardown')"; return; }

  ip netns add $CLI; ip netns add $RTR; ip netns add $SRV

  ip link add vc0 type veth peer name vr0
  ip link add vr1 type veth peer name vs0
  ip link set vc0 netns $CLI
  ip link set vr0 netns $RTR
  ip link set vr1 netns $RTR
  ip link set vs0 netns $SRV

  c ip addr add 10.10.1.2/24 dev vc0
  c ip link set vc0 up
  c ip link set lo up
  c ip route add default via 10.10.1.1

  r ip addr add 10.10.1.1/24 dev vr0
  r ip addr add 10.10.2.1/24 dev vr1
  r ip link set vr0 up; r ip link set vr1 up; r ip link set lo up
  r sysctl -qw net.ipv4.ip_forward=1

  s ip addr add 10.10.2.2/24 dev vs0
  s ip link set vs0 up
  s ip link set lo up
  s ip route add default via 10.10.2.1

  mkdir -p "$WWW"
  printf 'ok\n' > "$WWW/small.txt"
  head -c 2000000 /dev/urandom > "$WWW/big.bin"
  : > "$STATE/fault"

  start_server 10.10.2.2
  sleep 0.4

  ok "lab up."
  echo
  status
  echo
  note "try:  netlab test"
}

start_server() {
  local bind=$1
  stop_server
  s python3 -m http.server 8080 --bind "$bind" --directory "$WWW" \
      >"$STATE/server.log" 2>&1 &
  echo $! > "$STATE/server.pid"
  sleep 0.3
}

# The recorded PID belongs to `ip netns exec`, not to the python3 it execs,
# so killing it leaves the real server running -- which silently defeats any
# fault that depends on restarting the server, and leaks a listener on every
# reset. Match the command line instead; --directory makes it unambiguous.
stop_server() {
  pkill -f "http\.server 8080 .*--directory $WWW" 2>/dev/null || true
  rm -f "$STATE/server.pid"
  sleep 0.2
}

# ------------------------------------------------------------------ probe ---
test_probe() {
  exists || die "lab is not up - run: netlab setup"
  echo "── small object (one segment) ─────────────────────────────"
  c curl -m 8 -sS -o /dev/null \
      -w 'http %{http_code}   %{size_download} bytes   %{time_total}s\n' \
      http://10.10.2.2:8080/small.txt || echo "curl exit $?"
  echo
  echo "── large object (many full-size segments) ─────────────────"
  c curl -m 8 -sS -o /dev/null \
      -w 'http %{http_code}   %{size_download} bytes   %{time_total}s\n' \
      http://10.10.2.2:8080/big.bin || echo "curl exit $?"
}

status() {
  exists || die "lab is not up"
  printf '%-10s %s\n' "cli" "$(c ip -br addr show vc0 | tr -s ' ')"
  printf '%-10s %s\n' "rtr" "$(r ip -br addr show vr0 | tr -s ' ')"
  printf '%-10s %s\n' "rtr" "$(r ip -br addr show vr1 | tr -s ' ')"
  printf '%-10s %s\n' "srv" "$(s ip -br addr show vs0 | tr -s ' ')"
  local f; f=$(cat "$STATE/fault" 2>/dev/null || true)
  printf '%-10s %s\n' "fault" "$([ -n "$f" ] && echo 'injected (run: netlab reveal)' || echo none)"
}

# ------------------------------------------------------------------ reset ---
reset_all() {
  exists || die "lab is not up"
  r iptables -F; r iptables -t nat -F; r iptables -t mangle -F; r iptables -t raw -F
  r nft delete table inet lab 2>/dev/null || true
  s iptables -F 2>/dev/null || true
  r ip link set vr0 mtu 1500
  r ip link set vr1 mtu 1500
  s ip link set vs0 mtu 1500
  c ip link set vc0 mtu 1500
  s ip route replace default via 10.10.2.1
  c ip neigh del 10.10.1.1 dev vc0 2>/dev/null || true
  c ip neigh flush dev vc0 nud permanent 2>/dev/null || true
  start_server 10.10.2.2
  : > "$STATE/fault"
  ok "faults cleared."
}

# ------------------------------------------------------------------ fault ---
inject() {
  exists || die "lab is not up"
  local n=$1
  [ "$n" = random ] && n=$(( (RANDOM % FAULTS) + 1 ))
  case "$n" in [1-9]) ;; *) die "fault must be 1-$FAULTS or 'random'";; esac
  reset_all >/dev/null

  case $n in
    1) r iptables -A FORWARD -p tcp --dport 8080 -j DROP ;;
    2) r iptables -A FORWARD -p tcp --dport 8080 -j REJECT --reject-with tcp-reset ;;
    3) r iptables -A FORWARD -p tcp --dport 8080 -j REJECT --reject-with icmp-admin-prohibited ;;
    4) s ip route del default ;;
    # The constrained interface must be the one the router SENDS OUT toward the
    # client: the bulk data flows srv -> cli. Narrowing vr1 (which the router
    # only transmits on toward the server) constrains ACKs and nothing else,
    # so the black hole never opens and the fault silently does nothing.
    5) r ip link set vr0 mtu 1400
       r iptables -A OUTPUT -p icmp --icmp-type fragmentation-needed -j DROP ;;
    6) r iptables -t nat -A PREROUTING -d 10.10.2.2 -p tcp --dport 8080 \
            -j DNAT --to-destination 10.10.2.99:8080 ;;
    7) start_server 127.0.0.1 ;;
    8) r nft add table inet lab
       r nft add chain inet lab block '{ type filter hook forward priority 0; policy accept; }'
       r nft add rule inet lab block tcp dport 8080 drop ;;
    9) c ip neigh replace 10.10.1.1 lladdr 02:00:00:de:ad:01 dev vc0 nud permanent ;;
  esac

  echo "$n" > "$STATE/fault"
  sleep 0.3
  note "fault injected. you have not been told which one."
  note "reproduce it, diagnose it, then: netlab reveal"
}

# ----------------------------------------------------------------- reveal ---
reveal() {
  local n; n=$(cat "$STATE/fault" 2>/dev/null || true)
  [ -n "$n" ] || { note "no fault is currently injected."; return; }
  echo
  case $n in
    1) cat <<'T'
FAULT 1 - silent DROP in the router's FORWARD chain

  signature   connect hangs to the full timeout, SYNs repeat with identical
              seq, nothing ever comes back
  found by    tcpdump on cli: SYN out, no reply
              tcpdump on rtr vr1: nothing forwarded  <- loss is ON the router
              iptables -Z; retry; iptables -L -n -v  -> FORWARD rule counter climbing
  note        FORWARD, not INPUT: the packet is not addressed to the router.
T
;;
    2) cat <<'T'
FAULT 2 - REJECT --reject-with tcp-reset in FORWARD

  signature   fails instantly (~0.00s, not the 8s timeout), one packet each way
  found by    the timing alone rules out a silent DROP
              tcpdump: SYN out, R back immediately
              the RST's TTL is the router's, not the server's - a tell that
              something in the middle answered on the server's behalf
  note        curl reports this as "Couldn't connect to server". An instant
              refusal means a REJECT rule OR nothing listening (see fault 7).
T
;;
    3) cat <<'T'
FAULT 3 - REJECT --reject-with icmp-admin-prohibited in FORWARD

  signature   fails instantly, like fault 2, but for a different reason
  found by    tcpdump -nn icmp on cli ->
                ICMP host 10.10.2.2 unreachable - admin prohibited filter,
                sourced from 10.10.1.1
              the ICMP source address names the box holding the rule
  note        curl's own message ("Couldn't connect to server") does not
              distinguish this from fault 2 or fault 7. Only the capture does.
T
;;
    4) cat <<'T'
FAULT 4 - the server has no route back to the client

  signature   connect hangs exactly like a DROP - but no firewall rule exists
  found by    capture on BOTH ends. cli: SYN out, nothing back.
              srv: SYN arrives, and nothing leaves. The packet got there.
              then, on srv:  ip route get 10.10.1.2   ->  unreachable
  note        this is the fault that teaches why one-ended captures lie.
T
;;
    5) cat <<'T'
FAULT 5 - PMTU black hole (rtr vr0 MTU 1400, ICMP frag-needed dropped)

  signature   small.txt succeeds, big.bin hangs and transfers 0 bytes.
              ping works. looks like an application bug.
  found by    tcpdump on srv: the same full-size segment, same seq, resent
              over and over (filter: 'tcp and src 10.10.2.2 and len > 1000')
              tcpdump -nn icmp on srv: nothing - the frag-needed never arrives
              ip link show on each hop -> the 1400 stands out
  fix         raise the MTU, stop filtering ICMP, or clamp:
              iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN \
                  -j TCPMSS --clamp-mss-to-pmtu
  note        the narrowed link is the one the router transmits on toward the
              CLIENT, because that is the direction the bulk data flows.
T
;;
    6) cat <<'T'
FAULT 6 - DNAT to a host that does not exist

  signature   fails after a few seconds (ARP resolution has to time out first);
              the server never sees anything at all
  found by    tcpdump -e on rtr vr1 -> ARP "who-has 10.10.2.99", no reply
              r ip neigh  ->  10.10.2.99 INCOMPLETE
              iptables -t nat -L -n -v  ->  the DNAT rule, counters climbing
  note        -t nat is a separate table. "iptables -L" does not show it.
T
;;
    7) cat <<'T'
FAULT 7 - the server is bound to 127.0.0.1 only

  signature   fails instantly - identical to a REJECT rule from the outside
  found by    every firewall table on every hop is empty. that is the clue.
              srv: ss -ltnp  ->  LISTEN 127.0.0.1:8080, not 10.10.2.2:8080
              tcpdump on srv shows the SYN arriving and the srv kernel sending R
  note        an instant RST means REJECT *or* nothing listening on that address.
T
;;
    8) cat <<'T'
FAULT 8 - an nftables rule that "iptables -L" cannot see

  signature   silent DROP, and iptables -L -n -v across all four tables is clean
  found by    r nft list ruleset   ->  table inet lab, chain block,
                                       tcp dport 8080 drop
  note        on a modern host iptables is a shim over the same engine nft drives.
              Docker, k8s, firewalld and libvirt all write rules you did not.
              Never conclude "the firewall is innocent" from iptables -L alone.
T
;;
    9) cat <<'T'
FAULT 9 - a poisoned permanent ARP entry on the client

  signature   silent DROP, no firewall rule anywhere, server sees nothing
  found by    c ip neigh  ->  10.10.1.1 PERMANENT with a MAC nobody owns
              tcpdump -e on cli: frames leaving to 02:00:00:de:ad:01
              tcpdump -e on rtr vr0: the frames DO show up here, addressed to
              that bogus MAC -- tcpdump taps the device before the kernel's
              MAC filter runs. Compare against `ip link show vr0`: the
              destination does not match the interface's real address.
              tcpdump on rtr vr1: nothing forwarded. That gap -- arrives on
              one side, never leaves the other -- is the actual signal.
  note        layer 2. no IP-level tool would ever have told you.
              and note carefully: a packet APPEARING in tcpdump does not mean
              the kernel accepted it. tcpdump sees it; the MAC filter drops it.
T
;;
  esac
  echo
}

teardown() {
  need_root
  stop_server
  for n in $CLI $RTR $SRV; do ip netns del $n 2>/dev/null || true; done
  rm -rf "$STATE"
  ok "lab removed."
}

mkdir -p "$STATE"

case "${1:-help}" in
  setup)     setup ;;
  test)      test_probe ;;
  status)    status ;;
  fault)     inject "${2:-random}" ;;
  reset)     reset_all ;;
  reveal)    reveal ;;
  teardown)  teardown ;;
  cli)       shift; c "$@" ;;
  rtr)       shift; r "$@" ;;
  srv)       shift; s "$@" ;;
  *)         sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
