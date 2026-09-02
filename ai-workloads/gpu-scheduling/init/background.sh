#!/bin/bash

# nothing to install - this scenario needs no images beyond what the cluster
# already has. Just record the node name so the steps can refer to it.
kubectl get nodes -o jsonpath='{.items[0].metadata.name}' > /root/nodename

touch /tmp/.initfinished
