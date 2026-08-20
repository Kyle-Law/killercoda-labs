#!/bin/bash

# target a worker node specifically, not whichever node happens to be first -
# the control-plane node likely already carries its own stock taint, and
# stacking a second taint on it would make "tolerate my custom taint" alone
# insufficient to actually get scheduled there
NODE=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$NODE" ]; then
  NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
fi
echo "$NODE" > /root/tainted-node.txt

kubectl taint node "$NODE" dedicated=infra:NoSchedule --overwrite

touch /tmp/step2-applied
