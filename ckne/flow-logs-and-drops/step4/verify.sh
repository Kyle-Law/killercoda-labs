#!/bin/bash

# The policy must exist, select api, and permit web on the container port.
POL=$(kubectl get netpol api-allow-web -o json 2>/dev/null) || exit 1
echo "$POL" | grep -q '"app": *"api"' || exit 1
echo "$POL" | grep -q '"app": *"web"' || exit 1
echo "$POL" | grep -q '8080' || exit 1

# A leftover blanket deny would make the "blocked" half true for the wrong
# reason, so the tight policy has to be the one in force.
kubectl get netpol api-deny >/dev/null 2>&1 && exit 1

# Now prove it from the flow log, scoped to after the change: web forwarded,
# scanner dropped. Retried because both sides poll on their own timers.
for _ in $(seq 1 18); do
  FWD=$(kubectl -n kube-system exec ds/cilium -c cilium-agent -- \
    hubble observe --since 25s --to-pod api --verdict FORWARDED 2>/dev/null)
  DROP=$(kubectl -n kube-system exec ds/cilium -c cilium-agent -- \
    hubble observe --since 25s --to-pod api --verdict DROPPED 2>/dev/null)

  echo "$FWD" | grep -q "default/web" || { sleep 5; continue; }
  echo "$DROP" | grep -q "default/scanner" || { sleep 5; continue; }
  # ...and the scanner must NOT be getting through any more.
  echo "$FWD" | grep -q "default/scanner" && { sleep 5; continue; }
  exit 0
done

exit 1
