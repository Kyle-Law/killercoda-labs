#!/bin/bash

ORIGINAL=$(tr -d '[:space:]' < /root/original-rs.txt 2>/dev/null)
[ -n "$ORIGINAL" ] || exit 1

kubectl get rs "$ORIGINAL" >/dev/null 2>&1 || exit 1

# original RS must still exist (not deleted) but scaled to 0
ORIG_DESIRED=$(kubectl get rs "$ORIGINAL" -o jsonpath='{.spec.replicas}' 2>/dev/null)
[ "$ORIG_DESIRED" == "0" ] || exit 1

# a different RS for pi-web must now be running all 3
RS_COUNT=$(kubectl get rs -l app=pi-web --no-headers 2>/dev/null | wc -l)
[ "$RS_COUNT" -ge 2 ] || exit 1

NEW_READY=$(kubectl get rs -l app=pi-web -o jsonpath='{range .items[?(@.spec.replicas==3)]}{.status.readyReplicas}{end}')
[ "$NEW_READY" == "3" ]
