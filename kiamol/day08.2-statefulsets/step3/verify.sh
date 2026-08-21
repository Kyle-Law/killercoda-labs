#!/bin/bash

PARTITION=$(kubectl get statefulset db -o jsonpath='{.spec.updateStrategy.rollingUpdate.partition}' 2>/dev/null)
[ "$PARTITION" == "2" ] || exit 1

SPEC_IMG=$(kubectl get statefulset db -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
[ "$SPEC_IMG" == "busybox:1.36" ] || exit 1

IMG2=""
READY2=""
for i in $(seq 1 8); do
  IMG2=$(kubectl get pod db-2 -o jsonpath='{.spec.containers[0].image}' 2>/dev/null)
  READY2=$(kubectl get pod db-2 -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
  [ "$IMG2" == "busybox:1.36" ] && [ "$READY2" == "true" ] && break
  sleep 5
done
[ "$IMG2" == "busybox:1.36" ] && [ "$READY2" == "true" ] || exit 1

IMG0=$(kubectl get pod db-0 -o jsonpath='{.spec.containers[0].image}' 2>/dev/null)
IMG1=$(kubectl get pod db-1 -o jsonpath='{.spec.containers[0].image}' 2>/dev/null)
[ "$IMG0" == "busybox" ] || exit 1
[ "$IMG1" == "busybox" ] || exit 1

READY0=$(kubectl get pod db-0 -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
READY1=$(kubectl get pod db-1 -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
[ "$READY0" == "true" ] && [ "$READY1" == "true" ]
