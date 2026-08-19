#!/bin/bash

echo "Breaking the kube-apiserver..."
while [ ! -f /tmp/step3-applied ]; do sleep 1; done

# kubectl won't be usable to check this one - give the kubelet time to
# notice the manifest change and crash-loop the container
sleep 15

echo "Ready. Good luck! (kubectl won't respond until you fix this.)"
