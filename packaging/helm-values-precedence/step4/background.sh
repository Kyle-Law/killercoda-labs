#!/bin/bash

helm repo add podinfo https://stefanprodan.github.io/podinfo >/dev/null 2>&1
helm repo update >/dev/null 2>&1

printf '%s' "podinfo release notes: fixed the widget, added retries" > /root/release-notes.txt

helm install podinfo-values4 podinfo/podinfo --version 6.5.4 --wait --timeout 90s

touch /tmp/step4-applied
