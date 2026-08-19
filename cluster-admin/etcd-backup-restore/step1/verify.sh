#!/bin/bash

[ -f /root/etcd-snapshot.db ] || exit 1

# a real snapshot of a live cluster is comfortably more than a few KB
SIZE=$(stat -c%s /root/etcd-snapshot.db 2>/dev/null || echo 0)
[ "$SIZE" -gt 1000 ]
