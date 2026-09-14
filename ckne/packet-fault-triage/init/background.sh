#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

MISSING=""
for t in ip iptables nft tcpdump curl python3; do
  command -v "$t" >/dev/null 2>&1 || MISSING="$MISSING $t"
done

if [ -n "$MISSING" ]; then
  apt-get update -qq >/dev/null 2>&1
  apt-get install -y -qq iproute2 iptables nftables tcpdump curl python3 >/dev/null 2>&1
fi

# The `assets` block in index.json delivers netlab.sh to /usr/local/bin. The
# lab text invokes it as `netlab`, so expose it under that name -- searching a
# couple of plausible drop points rather than assuming one.
for CANDIDATE in /usr/local/bin/netlab.sh /root/netlab.sh "$(dirname "$0")/../assets/netlab.sh"; do
  if [ -f "$CANDIDATE" ]; then
    install -m 0755 "$CANDIDATE" /usr/local/bin/netlab
    break
  fi
done

mkdir -p /root/answers

netlab setup >/dev/null 2>&1

# Faults are assigned per step rather than drawn at random, so each step's
# verification knows what it is checking and the difficulty rises deliberately.
# Each step's verify.sh injects the next one on success.
netlab fault 1 >/dev/null 2>&1


# Killercoda shows only pass/fail, never a verify script's output, so each
# check writes its reason to /root/.check and `why` prints it.
cat > /usr/local/bin/why <<'WRAP'
#!/bin/bash
if [ -s /root/.check ]; then
  cat /root/.check
else
  echo "No check has run yet -- press CHECK, then run 'why' again."
fi
WRAP
chmod +x /usr/local/bin/why

touch /tmp/.initfinished
