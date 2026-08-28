#!/bin/bash

[ -f /root/releases ] || exit 1

# every 6.5.x patch must be listed, not just the newest
for v in 6.5.0 6.5.1 6.5.2 6.5.3 6.5.4; do
  grep -q "$v" /root/releases || exit 1
done

# and it must be scoped to 6.5 - a bare 'helm search repo podinfo' listing
# would only have the newest version, and an unscoped -l would include 6.4.x
if grep -q "6\.4\." /root/releases; then exit 1; fi

exit 0
