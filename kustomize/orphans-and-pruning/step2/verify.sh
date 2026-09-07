#!/bin/bash

[ -s /root/orphans.txt ] || exit 1

# the orphan must have been identified
grep -qx "legacy-flags" /root/orphans.txt || exit 1

# and the managed resources must NOT be listed as orphans
grep -qx "app-settings" /root/orphans.txt && exit 1
grep -qx "feature-toggles" /root/orphans.txt && exit 1

# the service-account CA bundle is injected into every namespace and is not
# an orphan in any meaningful sense
grep -qx "kube-root-ca.crt" /root/orphans.txt && exit 1

exit 0
