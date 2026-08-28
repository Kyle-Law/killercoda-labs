#!/bin/bash

helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo update

# revision 1
helm install webserver podinfo/podinfo --set ui.message="release one" --wait

# revision 2 - the last good one
helm upgrade webserver podinfo/podinfo --set ui.message="release two" --wait

# revision 3 - deploys fine as far as Helm is concerned, but the image tag
# doesn't exist, so the Pods never come up. No --wait here: we want the
# release to reach 'deployed' so it shows up in history as the current one.
helm upgrade webserver podinfo/podinfo \
  --set ui.message="release three" \
  --set image.tag=does-not-exist

touch /tmp/.initfinished
